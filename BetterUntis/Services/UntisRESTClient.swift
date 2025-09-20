import Foundation

/// Modern REST API client for BetterUntis API endpoints
@MainActor
class UntisRESTClient: ObservableObject {

    // MARK: - Properties

    private let session: URLSession
    private let keychain: KeychainManager
    private var baseURL: String
    private var schoolName: String

    @Published var isAuthenticated = false
    @Published var authToken: String?
    @Published var lastError: Error?

    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = DateFormatter.untisDateTime
            let stringValue = formatter.string(from: date)
            var container = encoder.singleValueContainer()
            try container.encode(stringValue)
        }
        return encoder
    }()

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let stringValue = try container.decode(String.self)

            // Try different date formats
            let formatters = [
                DateFormatter.untisDateTime,
                DateFormatter.untisDate,
                DateFormatter.untisTime
            ]

            for formatter in formatters {
                if let date = formatter.date(from: stringValue) {
                    return date
                }
            }

            // Fallback to ISO8601
            if let date = ISO8601DateFormatter().date(from: stringValue) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(stringValue)")
        }
        return decoder
    }()

    // MARK: - Initialization

    init(baseURL: String, schoolName: String, keychain: KeychainManager = KeychainManager.shared) {
        self.session = URLSession.shared
        self.keychain = keychain
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.schoolName = schoolName

        // Load stored token
        loadStoredToken()
    }

    // MARK: - Authentication

    /// Authenticate using the BetterUntis mobile API
    func authenticate(username: String, password: String) async throws -> AuthResponse {
        let endpoint = "/\(schoolName)/authentication"
        let url = URL(string: baseURL + endpoint)!

        let request = AuthRequest(username: username, password: password, client_id: "MOBILE")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try jsonEncoder.encode(request)

        print("🔐 REST Authentication request to: \(url)")

        do {
            let (data, response) = try await session.data(for: urlRequest)

            if let httpResponse = response as? HTTPURLResponse {
                print("🔐 REST Auth response status: \(httpResponse.statusCode)")

                guard httpResponse.statusCode == 200 else {
                    if let errorData = try? jsonDecoder.decode(UntisAPIError.self, from: data) {
                        throw errorData
                    }
                    throw UntisAPIError(code: httpResponse.statusCode, message: "Authentication failed", details: nil, timestamp: Date())
                }
            }

            let authResponse = try jsonDecoder.decode(AuthResponse.self, from: data)

            // Store token securely
            await storeToken(authResponse.access_token)

            print("✅ REST Authentication successful")
            return authResponse

        } catch {
            print("❌ REST Authentication failed: \(error)")
            lastError = error
            throw error
        }
    }

    /// Refresh the authentication token
    func refreshToken(_ refreshToken: String) async throws -> AuthResponse {
        let endpoint = "/\(schoolName)/authentication/refresh"
        let url = URL(string: baseURL + endpoint)!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw UntisAPIError(code: httpResponse.statusCode, message: "Token refresh failed", details: nil, timestamp: Date())
            }
        }

        let authResponse = try jsonDecoder.decode(AuthResponse.self, from: data)
        await storeToken(authResponse.access_token)

        return authResponse
    }

    // MARK: - Timetable API

    /// Get timetable data using REST API v3
    func getTimetable(
        elementType: RESTElementType,
        elementId: Int,
        startDate: Date,
        endDate: Date,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> TimetableResponse {

        guard let token = authToken else {
            throw UntisAPIError(code: 401, message: "Not authenticated", details: "No auth token available", timestamp: Date())
        }

        let dateFormatter = DateFormatter.untisDate
        let startDateStr = dateFormatter.string(from: startDate)
        let endDateStr = dateFormatter.string(from: endDate)

        var components = URLComponents(string: baseURL + "/api/rest/extern/v3/timetable")!
        components.queryItems = [
            URLQueryItem(name: "elementType", value: elementType.rawValue),
            URLQueryItem(name: "elementId", value: String(elementId)),
            URLQueryItem(name: "startDate", value: startDateStr),
            URLQueryItem(name: "endDate", value: endDateStr),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        print("📅 REST Timetable request: \(components.url!)")

        do {
            let (data, response) = try await session.data(for: urlRequest)

            if let httpResponse = response as? HTTPURLResponse {
                print("📅 REST Timetable response status: \(httpResponse.statusCode)")

                guard httpResponse.statusCode == 200 else {
                    if let errorData = try? jsonDecoder.decode(UntisAPIError.self, from: data) {
                        throw errorData
                    }
                    throw UntisAPIError(code: httpResponse.statusCode, message: "Timetable request failed", details: nil, timestamp: Date())
                }
            }

            let timetableResponse = try jsonDecoder.decode(TimetableResponse.self, from: data)
            print("✅ REST Timetable received \(timetableResponse.data.result.elements.count) periods")

            return timetableResponse

        } catch {
            print("❌ REST Timetable failed: \(error)")
            lastError = error
            throw error
        }
    }

    // MARK: - User Data API

    /// Get user data from mobile API
    func getUserData() async throws -> [String: Any] {
        guard let token = authToken else {
            throw UntisAPIError(code: 401, message: "Not authenticated", details: nil, timestamp: Date())
        }

        let url = URL(string: baseURL + "/view/v1/mobile/data")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw UntisAPIError(code: httpResponse.statusCode, message: "User data request failed", details: nil, timestamp: Date())
            }
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json ?? [:]
    }

    // MARK: - Token Management

    private func loadStoredToken() {
        if let token = keychain.getString(for: "untis_rest_token_\(schoolName)") {
            authToken = token
            isAuthenticated = true
            print("🔑 Loaded stored REST token for \(schoolName)")
        }
    }

    private func storeToken(_ token: String) async {
        authToken = token
        isAuthenticated = true
        keychain.set(token, for: "untis_rest_token_\(schoolName)")
        print("🔑 Stored REST token for \(schoolName)")
    }

    func clearToken() {
        authToken = nil
        isAuthenticated = false
        keychain.delete(for: "untis_rest_token_\(schoolName)")
        print("🔑 Cleared REST token for \(schoolName)")
    }

    // MARK: - Utility Methods

    /// Test connection to the REST API
    func testConnection() async -> Bool {
        let url = URL(string: baseURL + "/api/rest/extern/v3/timetable")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "OPTIONS"
        urlRequest.timeoutInterval = 10

        do {
            let (_, response) = try await session.data(for: urlRequest)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode < 400
            }
            return false
        } catch {
            print("❌ REST connection test failed: \(error)")
            return false
        }
    }

    /// Convert TimetableElement to Period for compatibility
    func convertTimetableToPeriods(_ elements: [TimetableElement]) -> [Period] {
        return elements.compactMap { element in
            guard let dateStr = element.date.split(separator: "T").first else { return nil }
            guard let date = DateFormatter.untisDate.date(from: String(dateStr)) else { return nil }

            let subject = element.su?.first?.name ?? element.su?.first?.longname ?? ""
            let teacher = element.te?.first?.name ?? element.te?.first?.longname ?? ""
            let room = element.ro?.first?.name ?? element.ro?.first?.longname ?? ""
            let className = element.kl?.first?.name ?? element.kl?.first?.longname ?? ""

            return Period(
                id: element.id,
                date: date,
                startTime: element.startTime,
                endTime: element.endTime,
                subject: subject,
                teacher: teacher,
                room: room,
                className: className,
                activityType: element.activityType ?? "lesson",
                code: element.code,
                info: element.info,
                substitutionText: element.bkText,
                cellState: element.cellState ?? "REGULAR"
            )
        }
    }
}

// MARK: - Extensions

extension UntisRESTClient {
    /// Create configured instance for a WebUntis server
    static func create(for serverURL: String, schoolName: String) -> UntisRESTClient {
        // Convert WebUntis URL to REST API base URL
        let baseURL = serverURL.replacingOccurrences(of: "/WebUntis", with: "")
        return UntisRESTClient(baseURL: baseURL, schoolName: schoolName)
    }
}