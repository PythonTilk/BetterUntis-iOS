import Foundation
import CoreData
import Combine

class UserRepository: ObservableObject {
    private let apiClient = UntisAPIClient()
    private let keychainManager = KeychainManager.shared
    private let persistenceController = PersistenceController.shared

    @Published var currentUser: User?
    @Published var hasActiveUser: Bool = false
    @Published var isLoading: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadCurrentUser()
    }

    // MARK: - User Management

    func loadCurrentUser() {
        // Load the most recently used user from Core Data
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UserEntity.created, ascending: false)]
        request.fetchLimit = 1

        do {
            let users = try context.fetch(request)
            if let userEntity = users.first {
                self.currentUser = userEntity.toDomainModel()
                self.hasActiveUser = true
            }
        } catch {
            print("Failed to load current user: \(error)")
        }
    }

    func getAllUsers() -> [User] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UserEntity.created, ascending: false)]

        do {
            return try context.fetch(request).map { $0.toDomainModel() }
        } catch {
            print("Failed to fetch users: \(error)")
            return []
        }
    }

    func switchToUser(_ user: User) {
        self.currentUser = user
        self.hasActiveUser = true
    }

    func deleteUser(_ user: User) throws {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %lld", user.id)

        do {
            let users = try context.fetch(request)
            if let userEntity = users.first {
                context.delete(userEntity)
                try context.save()

                // Also delete keychain data
                _ = keychainManager.deleteUserCredentials(userId: String(user.id))

                // If this was the current user, clear it
                if currentUser?.id == user.id {
                    currentUser = nil
                    hasActiveUser = false
                    loadCurrentUser() // Load another user if available
                }
            }
        } catch {
            throw error
        }
    }

    // MARK: - Authentication

    func login(server: String, school: String, username: String, password: String) async throws -> User {
        isLoading = true
        defer { isLoading = false }

        do {
            // Build API URL using WebUntisURLParser (try standard endpoint first)
            let jsonRpcApiUrl = WebUntisURLParser.buildJsonRpcApiUrl(server: server, school: school)

            var sessionId: String
            var finalApiUrl: String

            do {
                // Try standard endpoint first
                print("🔄 Attempting authentication with standard endpoint: \(jsonRpcApiUrl)")
                sessionId = try await apiClient.authenticate(
                    apiUrl: jsonRpcApiUrl,
                    user: username,
                    password: password
                )
                print("✅ Authentication successful with standard endpoint")
                finalApiUrl = jsonRpcApiUrl
            } catch {
                print("❌ Standard endpoint failed with error: \(error)")
                // If standard endpoint fails with method not found, try alternative endpoint
                if let nsError = error as NSError?,
                   nsError.code == -32601 {
                    print("🔄 Standard endpoint failed with method not found, trying alternative endpoint...")
                    let alternativeApiUrl = WebUntisURLParser.buildAlternativeJsonRpcApiUrl(server: server, school: school)
                    print("🔄 Attempting authentication with alternative endpoint: \(alternativeApiUrl)")

                    sessionId = try await apiClient.authenticate(
                        apiUrl: alternativeApiUrl,
                        user: username,
                        password: password
                    )
                    print("✅ Authentication successful with alternative endpoint")
                    finalApiUrl = alternativeApiUrl
                } else {
                    print("❌ Rethrowing authentication error: \(error)")
                    throw error
                }
            }

            // Try to get user data using sessionId and the final working API URL
            print("🔄 Attempting to get user data from: \(finalApiUrl)")

            var masterId: Int64
            var displayName: String
            var schoolName: String

            do {
                let userDataResult = try await apiClient.getUserData(
                    apiUrl: finalApiUrl,
                    user: username,
                    key: sessionId
                )
                print("✅ getUserData successful")

                // Parse user data from dictionary
                guard let userMasterId = userDataResult["masterId"] as? Int64,
                      let userDisplayName = userDataResult["displayName"] as? String,
                      let userSchoolName = userDataResult["schoolName"] as? String else {
                    throw LoginError.invalidUserData
                }

                masterId = userMasterId
                displayName = userDisplayName
                schoolName = userSchoolName

            } catch {
                print("❌ getUserData failed: \(error)")

                // Check if this is a method not supported error
                if let nsError = error as NSError?, nsError.code == -32601 {
                    print("🔄 getUserData not supported, using fallback approach...")

                    // Create minimal user data without getUserData
                    // Some older WebUntis servers don't support getUserData method
                    // but authentication still works, so we create a basic profile
                    masterId = Int64.random(in: 10000...99999) // Generate unique ID
                    displayName = username // Use username as display name
                    schoolName = school // Use provided school name

                    print("✅ Using fallback user data - ID: \(masterId), Display: \(displayName), School: \(schoolName)")
                } else {
                    // Re-throw other errors
                    throw error
                }
            }

            // Create and save user
            let user = User(
                id: masterId,
                profileName: "",
                apiHost: server,
                displayName: displayName,
                schoolName: schoolName,
                anonymous: false,
                masterDataTimestamp: 0, // Will be updated when we implement master data fetching
                created: Date()
            )

            try saveUser(user)

            // Save credentials to keychain
            if !keychainManager.saveUserCredentials(userId: String(user.id), user: username, key: sessionId) {
                print("Failed to save user credentials to keychain")
            }

            // Save additional connection info for servers without getUserData
            UserDefaults.standard.set(finalApiUrl, forKey: "lastWorkingApiUrl_\(user.id)")
            print("💾 Saved working API URL for user \(user.id): \(finalApiUrl)")

            // Set as current user
            await MainActor.run {
                self.currentUser = user
                self.hasActiveUser = true
            }

            return user

        } catch {
            throw error
        }
    }

    func loginAnonymously(server: String, school: String) async throws -> User {
        isLoading = true
        defer { isLoading = false }

        // For anonymous login, we'll just create a minimal user
        // In a real implementation, you might want to fetch some basic school data
        let user = User(
            id: Int64.random(in: 1000...9999), // Generate random ID for anonymous users
            profileName: "Anonymous",
            apiHost: server,
            displayName: "Anonymous User",
            schoolName: school,
            anonymous: true,
            masterDataTimestamp: 0,
            created: Date()
        )

        try saveUser(user)

        await MainActor.run {
            self.currentUser = user
            self.hasActiveUser = true
        }

        return user
    }

    func logout() {
        if let user = currentUser {
            _ = keychainManager.deleteUserCredentials(userId: String(user.id))
        }
        currentUser = nil
        hasActiveUser = false
    }

    // MARK: - Private Helper Methods

    private func saveUser(_ user: User) throws {
        let context = persistenceController.container.viewContext

        // Check if user already exists
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %lld", user.id)

        do {
            let existingUsers = try context.fetch(request)
            let userEntity: UserEntity

            if let existing = existingUsers.first {
                userEntity = existing
            } else {
                userEntity = UserEntity(context: context)
            }

            userEntity.update(from: user)

            try context.save()
            persistenceController.save()

        } catch {
            throw error
        }
    }

    private func buildApiUrl(server: String) -> String {
        var host = server
        if !host.hasPrefix("http://") && !host.hasPrefix("https://") {
            host = "https://" + host
        }

        if !host.hasSuffix("/WebUntis") {
            if host.hasSuffix("/") {
                host += "WebUntis"
            } else {
                host += "/WebUntis"
            }
        }

        return host
    }

    private func buildJsonRpcApiUrl(apiUrl: String, schoolName: String) -> String {
        var components = URLComponents(string: apiUrl)!
        components.path += "/jsonrpc_intern.do"
        components.queryItems = [URLQueryItem(name: "school", value: schoolName)]
        return components.url!.absoluteString
    }

    // MARK: - User Credentials

    func getUserCredentials(for userId: Int64) -> UserCredentials? {
        return keychainManager.loadUserCredentials(userId: String(userId))
    }
}

// MARK: - Login Errors
enum LoginError: Error, LocalizedError {
    case invalidUserData
    case authenticationFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidUserData:
            return "Invalid user data received from server"
        case .authenticationFailed:
            return "Authentication failed"
        case .networkError:
            return "Network error occurred"
        }
    }
}