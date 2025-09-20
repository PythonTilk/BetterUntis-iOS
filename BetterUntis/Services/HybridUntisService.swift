import Foundation

/// Hybrid service that combines REST API, JSONRPC API, and HTML parsing fallback
@MainActor
class HybridUntisService: ObservableObject {

    // MARK: - Properties

    private let restClient: UntisRESTClient
    private let jsonrpcClient: UntisAPIClient
    // private let htmlParser: WebUntisHTMLParser // Will be added when package is integrated
    private let keychain: KeychainManager

    @Published var isAuthenticated = false
    @Published var currentAuthMethod: AuthMethod = .none
    @Published var serverCapabilities: ServerCapabilities?
    @Published var lastError: Error?

    // Configuration
    @Published var enableRESTAPI = true
    @Published var enableJSONRPC = true
    @Published var enableHTMLParsing = true
    @Published var preferRESTAPI = true

    // MARK: - Types

    enum AuthMethod: String, CaseIterable {
        case none = "none"
        case rest = "REST API"
        case jsonrpc = "JSONRPC"
        case html = "HTML Parser"
    }

    struct ServerCapabilities {
        let supportsRESTAPI: Bool
        let supportsJSONRPC: Bool
        let supportedJSONRPCMethods: [String]
        let supportsHTMLParsing: Bool
        let serverVersion: String?
        let lastChecked: Date

        var preferredMethod: AuthMethod {
            if supportsRESTAPI { return .rest }
            if supportsJSONRPC { return .jsonrpc }
            if supportsHTMLParsing { return .html }
            return .none
        }
    }

    // MARK: - Initialization

    init(baseURL: String, schoolName: String, keychain: KeychainManager = KeychainManager.shared) {
        self.restClient = UntisRESTClient.create(for: baseURL, schoolName: schoolName)
        self.jsonrpcClient = UntisAPIClient()
        self.keychain = keychain

        // Load cached capabilities
        loadServerCapabilities(for: "\(baseURL)_\(schoolName)")
    }

    // MARK: - Authentication

    /// Authenticate using the best available method
    func authenticate(username: String, password: String, serverURL: String, schoolName: String) async throws {
        print("🔐 Starting hybrid authentication...")

        // Test server capabilities if not cached or outdated
        if serverCapabilities == nil || isCapabilitiesCacheExpired() {
            await testServerCapabilities(serverURL: serverURL, schoolName: schoolName)
        }

        var authErrors: [AuthMethod: Error] = [:]
        let authOrder = determineAuthOrder()

        for method in authOrder {
            do {
                switch method {
                case .rest:
                    if enableRESTAPI && serverCapabilities?.supportsRESTAPI == true {
                        let _ = try await restClient.authenticate(username: username, password: password)
                        isAuthenticated = true
                        currentAuthMethod = .rest
                        print("✅ Authenticated via REST API")
                        return
                    }

                case .jsonrpc:
                    if enableJSONRPC && serverCapabilities?.supportsJSONRPC == true {
                        let userData = try await jsonrpcClient.authenticate(
                            username: username,
                            password: password,
                            server: serverURL,
                            schoolName: schoolName
                        )
                        isAuthenticated = true
                        currentAuthMethod = .jsonrpc
                        print("✅ Authenticated via JSONRPC")
                        return
                    }

                case .html:
                    if enableHTMLParsing && serverCapabilities?.supportsHTMLParsing == true {
                        // HTML parser authentication will be implemented when package is integrated
                        print("🔄 HTML parsing authentication not yet implemented")
                        continue
                    }

                case .none:
                    continue
                }
            } catch {
                authErrors[method] = error
                print("❌ Authentication failed for \(method.rawValue): \(error.localizedDescription)")
                continue
            }
        }

        // If all methods failed, throw the most relevant error
        let errorMessage = authErrors.map { "\($0.key.rawValue): \($0.value.localizedDescription)" }.joined(separator: ", ")
        lastError = NSError(domain: "HybridAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "All authentication methods failed: \(errorMessage)"])
        throw lastError!
    }

    // MARK: - Data Retrieval Methods

    /// Get timetable data using the best available method
    func getTimetable(
        elementType: ElementType,
        elementId: Int,
        startDate: Date,
        endDate: Date
    ) async throws -> [Period] {
        guard isAuthenticated else {
            throw NSError(domain: "HybridService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        var lastError: Error?

        // Try REST API first if preferred and available
        if currentAuthMethod == .rest || (preferRESTAPI && restClient.isAuthenticated) {
            do {
                let restElementType: RESTElementType
                switch elementType {
                case .klasse: restElementType = .klasse
                case .teacher: restElementType = .teacher
                case .subject: restElementType = .subject
                case .room: restElementType = .room
                case .student: restElementType = .student
                }

                let response = try await restClient.getTimetable(
                    elementType: restElementType,
                    elementId: elementId,
                    startDate: startDate,
                    endDate: endDate
                )
                let periods = restClient.convertTimetableToPeriods(response.data.result.elements)
                print("📅 Retrieved \(periods.count) periods via REST API")
                return periods
            } catch {
                print("⚠️ REST timetable failed, falling back to JSONRPC: \(error.localizedDescription)")
                lastError = error
            }
        }

        // Fallback to JSONRPC
        if currentAuthMethod == .jsonrpc || jsonrpcClient.isAuthenticated {
            do {
                let periods = try await jsonrpcClient.getTimetable(
                    elementType: elementType.rawValue == "STUDENT" ? 5 : 1, // Convert to JSONRPC type
                    elementId: elementId,
                    startDate: startDate,
                    endDate: endDate
                )
                print("📅 Retrieved \(periods.count) periods via JSONRPC")
                return periods
            } catch {
                print("⚠️ JSONRPC timetable failed, falling back to HTML: \(error.localizedDescription)")
                lastError = error
            }
        }

        // Final fallback to HTML parsing
        if enableHTMLParsing && currentAuthMethod == .html {
            // HTML parser timetable retrieval will be implemented when package is integrated
            print("🔄 HTML timetable parsing not yet implemented")
        }

        throw lastError ?? NSError(domain: "HybridService", code: -1, userInfo: [NSLocalizedDescriptionKey: "All timetable methods failed"])
    }

    /// Get student absences using the best available method
    func getStudentAbsences(startDate: Date, endDate: Date) async throws -> [StudentAbsence] {
        guard isAuthenticated else {
            throw NSError(domain: "HybridService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        var lastError: Error?

        // Try enhanced JSONRPC first (most likely to have absence data)
        if currentAuthMethod == .jsonrpc || jsonrpcClient.isAuthenticated {
            do {
                let absences = try await jsonrpcClient.getStudentAbsencesEnhanced(
                    startDate: startDate,
                    endDate: endDate
                )
                print("🏥 Retrieved \(absences.count) absences via enhanced JSONRPC")
                return absences
            } catch {
                print("⚠️ Enhanced JSONRPC absences failed, trying standard methods: \(error.localizedDescription)")
                lastError = error
            }
        }

        // Fallback to HTML parsing (most reliable for absence data)
        if enableHTMLParsing {
            // HTML parser absence retrieval will be implemented when package is integrated
            print("🔄 HTML absence parsing not yet implemented")
        }

        throw lastError ?? NSError(domain: "HybridService", code: -1, userInfo: [NSLocalizedDescriptionKey: "All absence methods failed"])
    }

    /// Get homework using the best available method
    func getHomework(startDate: Date, endDate: Date) async throws -> [HomeWork] {
        guard isAuthenticated else {
            throw NSError(domain: "HybridService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        var lastError: Error?

        // Try enhanced JSONRPC first
        if currentAuthMethod == .jsonrpc || jsonrpcClient.isAuthenticated {
            do {
                let homework = try await jsonrpcClient.getHomeworkEnhanced(
                    startDate: startDate,
                    endDate: endDate
                )
                print("📚 Retrieved \(homework.count) homework items via enhanced JSONRPC")
                return homework
            } catch {
                print("⚠️ Enhanced JSONRPC homework failed, falling back to HTML: \(error.localizedDescription)")
                lastError = error
            }
        }

        // Fallback to HTML parsing
        if enableHTMLParsing {
            // HTML parser homework retrieval will be implemented when package is integrated
            print("🔄 HTML homework parsing not yet implemented")
        }

        throw lastError ?? NSError(domain: "HybridService", code: -1, userInfo: [NSLocalizedDescriptionKey: "All homework methods failed"])
    }

    /// Get exams using the best available method
    func getExams(startDate: Date, endDate: Date) async throws -> [EnhancedExam] {
        guard isAuthenticated else {
            throw NSError(domain: "HybridService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        var lastError: Error?

        // Try enhanced JSONRPC first
        if currentAuthMethod == .jsonrpc || jsonrpcClient.isAuthenticated {
            do {
                let exams = try await jsonrpcClient.getExamsEnhanced(
                    startDate: startDate,
                    endDate: endDate
                )
                print("📝 Retrieved \(exams.count) exams via enhanced JSONRPC")
                return exams
            } catch {
                print("⚠️ Enhanced JSONRPC exams failed, falling back to HTML: \(error.localizedDescription)")
                lastError = error
            }
        }

        // Fallback to HTML parsing
        if enableHTMLParsing {
            // HTML parser exam retrieval will be implemented when package is integrated
            print("🔄 HTML exam parsing not yet implemented")
        }

        throw lastError ?? NSError(domain: "HybridService", code: -1, userInfo: [NSLocalizedDescriptionKey: "All exam methods failed"])
    }

    // MARK: - Server Capabilities Testing

    /// Test what capabilities the server supports
    func testServerCapabilities(serverURL: String, schoolName: String) async {
        print("🔍 Testing server capabilities...")

        var capabilities = ServerCapabilities(
            supportsRESTAPI: false,
            supportsJSONRPC: false,
            supportedJSONRPCMethods: [],
            supportsHTMLParsing: false,
            serverVersion: nil,
            lastChecked: Date()
        )

        // Test REST API
        if enableRESTAPI {
            capabilities.supportsRESTAPI = await restClient.testConnection()
            print("🌐 REST API support: \(capabilities.supportsRESTAPI)")
        }

        // Test JSONRPC API
        if enableJSONRPC {
            capabilities.supportsJSONRPC = await jsonrpcClient.testConnection(server: serverURL, schoolName: schoolName)
            if capabilities.supportsJSONRPC {
                // Test enhanced methods if JSONRPC works
                let supportedMethods = await jsonrpcClient.testBetterUntisSupport()
                capabilities.supportedJSONRPCMethods = supportedMethods.compactMap { $0.value ? $0.key : nil }
                print("📡 JSONRPC API support: \(capabilities.supportsJSONRPC) with \(capabilities.supportedJSONRPCMethods.count) enhanced methods")
            }
        }

        // Test HTML parsing capability (always assume available as fallback)
        if enableHTMLParsing {
            capabilities.supportsHTMLParsing = true
            print("🌐 HTML parsing support: \(capabilities.supportsHTMLParsing)")
        }

        serverCapabilities = capabilities
        saveServerCapabilities(for: "\(serverURL)_\(schoolName)", capabilities: capabilities)
    }

    // MARK: - Configuration Management

    private func determineAuthOrder() -> [AuthMethod] {
        guard let capabilities = serverCapabilities else {
            return preferRESTAPI ? [.rest, .jsonrpc, .html] : [.jsonrpc, .rest, .html]
        }

        var order: [AuthMethod] = []

        if preferRESTAPI {
            if capabilities.supportsRESTAPI { order.append(.rest) }
            if capabilities.supportsJSONRPC { order.append(.jsonrpc) }
            if capabilities.supportsHTMLParsing { order.append(.html) }
        } else {
            if capabilities.supportsJSONRPC { order.append(.jsonrpc) }
            if capabilities.supportsRESTAPI { order.append(.rest) }
            if capabilities.supportsHTMLParsing { order.append(.html) }
        }

        return order
    }

    private func isCapabilitiesCacheExpired() -> Bool {
        guard let capabilities = serverCapabilities else { return true }
        return Date().timeIntervalSince(capabilities.lastChecked) > 3600 // 1 hour cache
    }

    // MARK: - Persistence

    private func saveServerCapabilities(for key: String, capabilities: ServerCapabilities) {
        do {
            let data = try JSONEncoder().encode(capabilities)
            keychain.set(String(data: data, encoding: .utf8) ?? "", for: "capabilities_\(key)")
            print("💾 Saved server capabilities for \(key)")
        } catch {
            print("❌ Failed to save capabilities: \(error)")
        }
    }

    private func loadServerCapabilities(for key: String) {
        guard let jsonString = keychain.getString(for: "capabilities_\(key)"),
              let data = jsonString.data(using: .utf8) else { return }

        do {
            serverCapabilities = try JSONDecoder().decode(ServerCapabilities.self, from: data)
            print("📂 Loaded cached server capabilities for \(key)")
        } catch {
            print("❌ Failed to load capabilities: \(error)")
        }
    }

    // MARK: - Utility Methods

    /// Clear all authentication and reset state
    func logout() {
        restClient.clearToken()
        jsonrpcClient.logout()
        isAuthenticated = false
        currentAuthMethod = .none
        lastError = nil
        print("🚪 Logged out from all services")
    }

    /// Get current service status summary
    func getServiceStatus() -> [String: Any] {
        return [
            "isAuthenticated": isAuthenticated,
            "currentAuthMethod": currentAuthMethod.rawValue,
            "restAuthenticated": restClient.isAuthenticated,
            "jsonrpcAuthenticated": jsonrpcClient.isAuthenticated,
            "serverCapabilities": serverCapabilities?.preferredMethod.rawValue ?? "unknown",
            "enabledMethods": [
                "REST": enableRESTAPI,
                "JSONRPC": enableJSONRPC,
                "HTML": enableHTMLParsing
            ]
        ]
    }
}

// MARK: - Extensions

extension HybridUntisService.ServerCapabilities: Codable {}

extension HybridUntisService {
    /// Create configured instance for a WebUntis server
    static func create(for serverURL: String, schoolName: String) -> HybridUntisService {
        return HybridUntisService(baseURL: serverURL, schoolName: schoolName)
    }
}