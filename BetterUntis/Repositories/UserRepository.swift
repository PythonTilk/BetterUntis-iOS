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

    private func loadCurrentUser() {
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
                keychainManager.deleteUserCredentials(userId: String(user.id))

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
            // Build API URLs
            let apiUrl = buildApiUrl(server: server)
            let jsonRpcApiUrl = buildJsonRpcApiUrl(apiUrl: apiUrl, schoolName: school)

            // Get app shared secret
            let sharedSecret = try await apiClient.getAppSharedSecret(
                apiUrl: jsonRpcApiUrl,
                user: username,
                password: password
            )

            // Get auth token
            let authToken = try await apiClient.getAuthToken(
                apiUrl: jsonRpcApiUrl,
                user: username,
                key: sharedSecret
            )

            // Get user data
            let userDataResult = try await apiClient.getUserData(
                apiUrl: jsonRpcApiUrl,
                user: username,
                key: sharedSecret
            )

            // Create and save user
            let user = User(
                id: userDataResult.userData.masterId,
                profileName: "",
                apiHost: server,
                displayName: userDataResult.userData.displayName,
                schoolName: userDataResult.userData.schoolName,
                anonymous: false,
                masterDataTimestamp: userDataResult.masterData.timeStamp,
                created: Date()
            )

            try saveUser(user)

            // Save credentials to keychain
            if !keychainManager.saveUserCredentials(userId: String(user.id), user: username, key: sharedSecret) {
                print("Failed to save user credentials to keychain")
            }

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
            keychainManager.deleteUserCredentials(userId: String(user.id))
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