import Foundation
import CryptoKit

struct JSONRPCAuthenticationResult {
    let sessionId: String
    let personId: Int64?
    let personType: Int?
    let klasseId: Int64?
}

class UntisAPIClient {
    // MARK: - Constants
    static let defaultSchoolSearchURL = "https://mobile.webuntis.com/ms/schoolquery2"

    // Platform Application Identifiers
    static let applicationId = "BetterUntis-iOS"
    static let applicationVersion = "1.0.0"
    static let platformIdentifier = "iOS"
    static let clientName = "MOBILE_APP_NAME"
    static let developerId = "BetterUntis-Platform"
    static let userAgent = "BetterUntis/1.0.0 (iOS; iPhone; Mobile)"

    // API Methods
    static let methodCreateImmediateAbsence = "createImmediateAbsence2017"
    static let methodDeleteAbsence = "deleteAbsence2017"
    static let methodAuthenticate = "authenticate"
    static let methodGetAuthToken = "getAuthToken"
    static let methodGetAppSharedSecret = "getAppSharedSecret"
    static let methodAuthenticateWithSecret = "authenticate"

    // Fallback authentication methods for older servers
    static let methodAuthenticateFallback1 = "login"
    static let methodAuthenticateFallback2 = "authenticateUser"
    static let methodAuthenticateFallback3 = "validateUser"
    static let methodAuthenticateFallback4 = "loginUser"
    static let methodAuthenticateFallback5 = "userLogin"
    static let methodAuthenticateFallback6 = "auth"
    static let methodAuthenticateFallback7 = "signIn"
    static let methodGetCurrentSchoolYear = "getCurrentSchoolYear"
    static let methodGetExams = "getExams2017"
    static let methodGetHomeWork = "getHomeWork2017"
    static let methodGetMessagesOfDay = "getMessagesOfDay2017"
    static let methodGetPeriodData = "getPeriodData2017"
    static let methodGetRooms = "getRooms" // No 2017 version - will use master data
    static let methodGetStudentAbsences = "getStudentAbsences2017"
    static let methodGetTimetable = "getTimetable2017"
    static let methodGetUserData = "getUserData2017"
    static let methodLogin = "login"
    static let methodLogout = "logout"
    static let methodSearchSchools = "searchSchools"

    // Fallback methods for older WebUntis versions
    static let methodGetTimetableFallback1 = "getOwnTimetableForToday"
    static let methodGetTimetableFallback2 = "getTimetableForToday"
    static let methodGetTimetableFallback3 = "getTimetableForElement"
    static let methodGetTimetableFallback4 = "getTimetableData"
    static let methodGetTimetableFallback5 = "getLessons"
    static let methodGetTimetableFallback6 = "getPeriods"

    // Additional fallback for very old servers (like mese.webuntis.com)
    static let methodGetLessons = "getLessons"
    static let methodGetMessagesFallback1 = "getMessages"
    static let methodGetMessagesFallback2 = "getNewsOfDay"
    static let methodGetHomeWorkFallback1 = "getHomework"
    static let methodGetHomeWorkFallback2 = "getHomeworks"
    static let methodGetRoomsFallback1 = "getRoomList"
    static let methodGetRoomsFallback2 = "getAllRooms"
    static let methodGetExamsFallback1 = "getExaminations"
    static let methodGetExamsFallback2 = "getTests"
    static let methodGetAbsencesFallback1 = "getStudentAbsences"
    static let methodGetAbsencesFallback2 = "getAbsences"

    // MARK: - Instance Properties
    private var sessionKey: String?
    private var sessionCookie: HTTPCookie?
    private var baseURL: String?

    var isAuthenticated: Bool {
        return sessionKey != nil && sessionCookie != nil
    }

    // MARK: - Utility Methods

    /// Checks if an error is a "method not found" error
    private static func isMethodNotFoundError(_ error: Error) -> Bool {
        if let nsError = error as NSError? {
            return nsError.code == -32601
        }
        return false
    }

    /// Extracts method not found error from JSON response
    private static func isMethodNotFoundInJSON(_ json: [String: Any]) -> Bool {
        if let error = json["error"] as? [String: Any],
           let code = error["code"] as? Int {
            return code == -32601
        }
        return false
    }

    // MARK: - Simple Network Methods
    func authenticate(
        apiUrl: String,
        user: String,
        password: String,
        client: String? = nil
    ) async throws -> JSONRPCAuthenticationResult {
        let clientValue = client ?? UntisAPIClient.clientName
        // Try different authentication methods in order
        let authMethods = [
            Self.methodAuthenticate,
            Self.methodAuthenticateFallback1,
            Self.methodAuthenticateFallback2,
            Self.methodAuthenticateFallback3,
            Self.methodAuthenticateFallback4,
            Self.methodAuthenticateFallback5,
            Self.methodAuthenticateFallback6,
            Self.methodAuthenticateFallback7
        ]

        var lastError: Error?

        for (index, method) in authMethods.enumerated() {
            do {
                DebugLogger.logAuthAttempt(method: "JSONRPC(\(method))", server: apiUrl, user: user)

                let authResult = try await performAuthentication(
                    apiUrl: apiUrl,
                    user: user,
                    password: password,
                    client: clientValue,
                    method: method
                )

                DebugLogger.logAuthSuccess(method: "JSONRPC(\(method))", user: user)
                return authResult

            } catch {
                lastError = error

                // Log the attempt failure
                DebugLogger.logAuthFailure(method: "JSONRPC(\(method))", user: user, error: error)

                // If this is a method not found error and we have more methods to try, continue
                if let nsError = error as NSError?, nsError.code == -32601, index < authMethods.count - 1 {
                    DebugLogger.logInfo("Authentication method '\(method)' not supported, trying next method...")
                    continue
                } else {
                    // For other errors (like wrong credentials), don't try more methods
                    if let nsError = error as NSError?, nsError.code != -32601 {
                        throw error
                    }
                }
            }
        }

        // If we get here, all methods failed
        let finalError = lastError ?? NSError(domain: "UntisAPI", code: -32601, userInfo: [NSLocalizedDescriptionKey: "All authentication methods failed"])
        trackError(finalError, context: "All authentication methods failed for \(user) on \(apiUrl)")
        throw finalError
    }

    private func performAuthentication(
        apiUrl: String,
        user: String,
        password: String,
        client: String,
        method: String
    ) async throws -> JSONRPCAuthenticationResult {
        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(Self.applicationId, forHTTPHeaderField: "X-Untis-Application-ID")
        request.setValue(Self.applicationVersion, forHTTPHeaderField: "X-Untis-Application-Version")
        request.setValue(Self.platformIdentifier, forHTTPHeaderField: "X-Untis-Platform")
        request.setValue(Self.developerId, forHTTPHeaderField: "X-Untis-Developer-ID")

        // Log network request
        let headers = [
            "Content-Type": "application/json",
            "User-Agent": Self.userAgent,
            "X-Untis-Application-ID": Self.applicationId
        ]
        DebugLogger.logNetworkRequest(url: apiUrl, method: "POST", headers: headers)

        // Create different request format based on method
        var requestData: [String: Any]

        if method == Self.methodAuthenticateFallback1 { // "login"
            // Some older servers use a simpler login format
            requestData = [
                "id": UUID().uuidString,
                "method": method,
                "params": [
                    "user": user,
                    "password": password,
                    "client": client
                ],
                "jsonrpc": "2.0"
            ]
        } else if method == Self.methodAuthenticateFallback2 { // "authenticateUser"
            // Alternative authentication format
            requestData = [
                "id": UUID().uuidString,
                "method": method,
                "params": [
                    "username": user,
                    "password": password
                ],
                "jsonrpc": "2.0"
            ]
        } else if method == Self.methodAuthenticateFallback3 { // "validateUser"
            // Very simple validation format
            requestData = [
                "id": UUID().uuidString,
                "method": method,
                "params": [user, password],
                "jsonrpc": "2.0"
            ]
        } else if method == Self.methodAuthenticateFallback4 { // "loginUser"
            // Login user format with minimal params
            requestData = [
                "id": UUID().uuidString,
                "method": method,
                "params": [
                    "user": user,
                    "password": password
                ],
                "jsonrpc": "2.0"
            ]
        } else if method == Self.methodAuthenticateFallback5 { // "userLogin"
            // User login format - positional params
            requestData = [
                "id": UUID().uuidString,
                "method": method,
                "params": [user, password, client],
                "jsonrpc": "2.0"
            ]
        } else if method == Self.methodAuthenticateFallback6 { // "auth"
            // Minimal auth format
            requestData = [
                "id": UUID().uuidString,
                "method": method,
                "params": [
                    "username": user,
                    "pwd": password
                ],
                "jsonrpc": "2.0"
            ]
        } else if method == Self.methodAuthenticateFallback7 { // "signIn"
            // Sign in format - ultra simple
            requestData = [
                "id": UUID().uuidString,
                "method": method,
                "params": [user, password],
                "jsonrpc": "2.0"
            ]
        } else {
            // Standard authentication format - simplified to match working curl format
            requestData = [
                "id": UUID().uuidString,
                "method": method,
                "params": [
                    "user": user,
                    "password": password,
                    "client": client
                ],
                "jsonrpc": "2.0"
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let startTime = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        // Log network response
        if let httpResponse = response as? HTTPURLResponse {
            DebugLogger.logNetworkResponse(url: apiUrl, statusCode: httpResponse.statusCode, responseSize: data.count, duration: duration)
        }

        // Debug response in verbose mode
        if DebugLogger.isVerboseLoggingEnabled, let responseString = String(data: data, encoding: .utf8) {
            DebugLogger.logDebug("Authentication response: \(responseString)", context: "API Response")
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [String: Any],
           let sessionId = result["sessionId"] as? String {
            sessionKey = sessionId

            // Store the base URL for future requests
            if let urlComponents = URLComponents(string: apiUrl) {
                var components = urlComponents
                components.query = nil // Remove query parameters for base URL
                baseURL = components.url?.absoluteString
            }

            // Create session cookie for this server
            if let baseURLString = baseURL,
               let cookieURL = URL(string: baseURLString) {
                sessionCookie = HTTPCookie(properties: [
                    .domain: cookieURL.host ?? "",
                    .path: "/",
                    .name: "JSESSIONID",
                    .value: sessionId,
                    .secure: "TRUE",
                    .expires: Date().addingTimeInterval(3600) // 1 hour expiry
                ])
            }

            let personId = (result["personId"] as? NSNumber)?.int64Value
            let personType = result["personType"] as? Int
            let klasseId = (result["klasseId"] as? NSNumber)?.int64Value

            return JSONRPCAuthenticationResult(
                sessionId: sessionId,
                personId: personId,
                personType: personType,
                klasseId: klasseId
            )
        } else if let result = json["result"] as? String {
            // Some methods return session ID directly as string
            sessionKey = result

            // Store the base URL for future requests
            if let urlComponents = URLComponents(string: apiUrl) {
                var components = urlComponents
                components.query = nil // Remove query parameters for base URL
                baseURL = components.url?.absoluteString
            }

            // Create session cookie for this server
            if let baseURLString = baseURL,
               let cookieURL = URL(string: baseURLString) {
                sessionCookie = HTTPCookie(properties: [
                    .domain: cookieURL.host ?? "",
                    .path: "/",
                    .name: "JSESSIONID",
                    .value: result,
                    .secure: "TRUE",
                    .expires: Date().addingTimeInterval(3600) // 1 hour expiry
                ])
            }

            return JSONRPCAuthenticationResult(
                sessionId: result,
                personId: nil,
                personType: nil,
                klasseId: nil
            )
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1

            // Provide more helpful error messages based on common WebUntis error codes
            let userFriendlyMessage: String
            switch code {
            case -8500:
                userFriendlyMessage = "Invalid school name. Please check that the school name in the URL is correct for this server."
            case -8504:
                userFriendlyMessage = "Invalid username or password."
            case -32601:
                userFriendlyMessage = "Authentication method not supported by this server."
            case -32600:
                userFriendlyMessage = "Invalid request format."
            default:
                userFriendlyMessage = message
            }

            let authError = NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: userFriendlyMessage])
            throw authError
        } else {
            let unknownError = NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown authentication error"])
            throw unknownError
        }
    }

    // MARK: - Connection Management

    func testConnection(server: String, schoolName: String) async -> Bool {
        do {
            // Handle both complete API URLs and base server URLs
            let apiUrl: String
            if server.contains("jsonrpc.do") {
                // Already a complete API URL
                apiUrl = server
            } else {
                // Build complete API URL
                apiUrl = "\(server)?school=\(schoolName)"
            }

            print("🔍 Testing JSONRPC connection to: \(apiUrl)")
            _ = try await authenticate(apiUrl: apiUrl, user: "test", password: "test")
            return true
        } catch {
            // If we get a specific authentication error (like invalid credentials),
            // it means the connection is working but credentials are wrong
            if let nsError = error as NSError?, nsError.code == -8504 {
                print("✅ Server connection working (invalid test credentials as expected)")
                return true // Server is reachable and working
            }
            // If we get "not authenticated" errors, it means the API is working
            // but authentication failed (which is expected with test credentials)
            if let nsError = error as NSError?, nsError.code == -8520 {
                print("✅ Server connection working (authentication required as expected)")
                return true // Server is reachable and working
            }
            // If ALL authentication methods fail with "method not found",
            // this server doesn't support JSONRPC at all
            if let nsError = error as NSError?, nsError.code == -32601 {
                print("❌ Server doesn't support JSONRPC methods")
                return false // Server doesn't support JSONRPC
            }
            print("❌ Server connection failed: \(error.localizedDescription)")
            return false // Server is not reachable or not working
        }
    }

    func logout() async throws {
        // Clear the session key and cookie
        sessionKey = nil
        sessionCookie = nil
        baseURL = nil
        // Note: Most WebUntis servers don't require explicit logout for JSONRPC
        print("🔓 Logged out from JSONRPC session")
    }

    func getAuthToken(apiUrl: String, user: String?, key: String?) async throws -> String {
        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestData = [
            "id": UUID().uuidString,
            "method": Self.methodGetAuthToken,
            "params": [
                "auth": [
                    "user": user as Any,
                    "key": key as Any
                ]
            ],
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [String: Any],
           let token = result["token"] as? String {
            return token
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        }
    }

    func getAppSharedSecret(apiUrl: String, username: String, password: String) async throws -> String {
        print("🔄 UntisAPIClient.getAppSharedSecret - URL: \(apiUrl)")
        print("🔄 UntisAPIClient.getAppSharedSecret - User: \(username)")

        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(Self.applicationId, forHTTPHeaderField: "X-Untis-Application-ID")
        request.setValue(Self.applicationVersion, forHTTPHeaderField: "X-Untis-Application-Version")
        request.setValue(Self.platformIdentifier, forHTTPHeaderField: "X-Untis-Platform")
        request.setValue(Self.developerId, forHTTPHeaderField: "X-Untis-Developer-ID")

        let requestData = [
            "id": UUID().uuidString,
            "method": Self.methodGetAppSharedSecret,
            "params": [
                "userName": username,
                "password": password,
                "applicationId": Self.applicationId,
                "platformId": Self.platformIdentifier
            ],
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)

        if let responseString = String(data: data, encoding: .utf8) {
            print("getAppSharedSecret response: \(responseString)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [String: Any],
           let secret = result["secret"] as? String {
            return secret
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            throw NSError(domain: "UntisAPI", code: error["code"] as? Int ?? -1, userInfo: [NSLocalizedDescriptionKey: message])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error getting app shared secret"])
        }
    }

    func getUserData(apiUrl: String, user: String?, key: String?) async throws -> [String: Any] {
        print("🔄 UntisAPIClient.getUserData - URL: \(apiUrl)")
        print("🔄 UntisAPIClient.getUserData - User: \(user ?? "nil")")

        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestData = [
            "id": UUID().uuidString,
            "method": Self.methodGetUserData,
            "params": [
                "auth": [
                    "user": user as Any,
                    "key": key as Any
                ]
            ],
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [String: Any] {
            return result
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1

            // Provide more helpful error messages based on common WebUntis error codes
            let userFriendlyMessage: String
            switch code {
            case -8500:
                userFriendlyMessage = "Invalid school name. Please check that the school name in the URL is correct for this server."
            case -8504:
                userFriendlyMessage = "Invalid username or password."
            case -32601:
                userFriendlyMessage = "The getUserData method is not supported by this server. This may be an older WebUntis version."
            case -32600:
                userFriendlyMessage = "Invalid request format."
            default:
                userFriendlyMessage = message
            }

            throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: userFriendlyMessage])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error getting user data"])
        }
    }

    func getTimetable(
        apiUrl: String,
        id: Int64,
        type: ElementType,
        startDate: Date,
        endDate: Date,
        masterDataTimestamp: Int64,
        user: String?,
        key: String?
    ) async throws -> [String: Any] {
        // Try primary method first
        do {
            print("🔄 Trying primary getTimetable method...")
            return try await attemptGetTimetable(
                apiUrl: apiUrl,
                method: Self.methodGetTimetable,
                id: id,
                type: type,
                startDate: startDate,
                endDate: endDate,
                masterDataTimestamp: masterDataTimestamp,
                user: user,
                key: key,
                useFullParams: true
            )
        } catch {
            if Self.isMethodNotFoundError(error) {
                print("❌ Primary getTimetable method not found, trying fallbacks...")

                // Try fallback methods
                let fallbackMethods = [
                    Self.methodGetTimetableFallback1,
                    Self.methodGetTimetableFallback2,
                    Self.methodGetTimetableFallback3,
                    Self.methodGetTimetableFallback4,
                    Self.methodGetTimetableFallback5,
                    Self.methodGetTimetableFallback6
                ]

                for fallbackMethod in fallbackMethods {
                    do {
                        print("🔄 Trying fallback method: \(fallbackMethod)")
                        return try await attemptGetTimetable(
                            apiUrl: apiUrl,
                            method: fallbackMethod,
                            id: id,
                            type: type,
                            startDate: startDate,
                            endDate: endDate,
                            masterDataTimestamp: 0, // Older methods may not support this
                            user: user,
                            key: key,
                            useFullParams: false
                        )
                    } catch {
                        if !Self.isMethodNotFoundError(error) {
                            // If it's not a method not found error, it might be working but with different issues
                            print("⚠️ Method \(fallbackMethod) exists but has error: \(error.localizedDescription)")
                        }
                        continue
                    }
                }

                // Try ultra-basic fallback with minimal parameters
                print("🔄 Trying ultra-basic timetable fallback...")
                do {
                    return try await attemptBasicTimetable(
                        apiUrl: apiUrl,
                        startDate: startDate,
                        endDate: endDate,
                        user: user,
                        key: key
                    )
                } catch {
                    print("❌ Even basic timetable approach failed: \(error.localizedDescription)")
                }

                // Try getLessons as a last resort (returns lesson definitions rather than periods)
                print("🔄 Trying getLessons as ultimate fallback...")
                do {
                    return try await attemptGetLessons(
                        apiUrl: apiUrl,
                        id: id,
                        type: type,
                        startDate: startDate,
                        endDate: endDate,
                        user: user,
                        key: key
                    )
                } catch {
                    print("❌ Even getLessons failed: \(error.localizedDescription)")
                }

                // Ultimate fallback: return empty but valid structure
                print("⚠️ No timetable methods work - providing empty timetable structure")
                return [
                    "timetable": [],
                    "masterData": [:],
                    "serverMessage": "This WebUntis server version does not support automated timetable retrieval. Please check your timetable manually on the WebUntis website."
                ]
            } else {
                throw error
            }
        }
    }

    private func attemptGetTimetable(
        apiUrl: String,
        method: String,
        id: Int64,
        type: ElementType,
        startDate: Date,
        endDate: Date,
        masterDataTimestamp: Int64,
        user: String?,
        key: String?,
        useFullParams: Bool
    ) async throws -> [String: Any] {
        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add session cookie if available
        if let sessionCookie = sessionCookie {
            request.setValue("JSESSIONID=\(sessionCookie.value)", forHTTPHeaderField: "Cookie")
        }

        let startDateInt = formatDateInt(startDate)
        let endDateInt = formatDateInt(endDate)

        var timetableParams: [String: Any] = [
            "id": id,
            "type": type.apiValue,
            "startDate": startDateInt,
            "endDate": endDateInt
        ]

        if useFullParams {
            timetableParams["masterDataTimestamp"] = masterDataTimestamp
            timetableParams["timetableTimestamp"] = 0
            timetableParams["timetableTimestamps"] = []
        }

        if let authParams = makeAuthParameters(user: user, key: key) {
            timetableParams["auth"] = authParams
        }

        let requestData: [String: Any] = [
            "id": UUID().uuidString,
            "method": method,
            "params": [timetableParams],
            "jsonrpc": "2.0"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        print("📊 Raw timetable response for method \(method):")
        if let responseData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let responseString = String(data: responseData, encoding: .utf8) {
            print("📊 \(responseString)")
        }

        if let result = json["result"] as? [String: Any] {
            print("📊 Timetable result received (dictionary format):")
            print("📊 Keys: \(Array(result.keys))")
            if let timetable = result["timetable"] as? [[String: Any]] {
                print("📊 Timetable array contains \(timetable.count) periods")
                if let firstPeriod = timetable.first {
                    print("📊 First period keys: \(Array(firstPeriod.keys))")
                }
            } else {
                print("📊 No 'timetable' key found in result")
            }
            return result
        } else if let result = json["result"] as? [[String: Any]] {
            print("📊 Timetable result received (array format):")
            print("📊 Array contains \(result.count) items")
            if let firstItem = result.first {
                print("📊 First item keys: \(Array(firstItem.keys))")
            }
            return ["timetable": result]
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1
            throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        }
    }

    private func attemptBasicTimetable(
        apiUrl: String,
        startDate: Date,
        endDate: Date,
        user: String?,
        key: String?
    ) async throws -> [String: Any] {
        // Try the most basic approaches for very old servers
        let basicMethods = ["getMyTimetable", "getStudentTimetable", "getCurrentTimetable"]

        for method in basicMethods {
            do {
                print("🔄 Trying ultra-basic method: \(method)")

                let url = URL(string: apiUrl)!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                // Add session cookie if available
                if let sessionCookie = sessionCookie {
                    request.setValue("JSESSIONID=\(sessionCookie.value)", forHTTPHeaderField: "Cookie")
                }

                // Minimal parameters - use auth payload when possible
                var params: [String: Any] = [:]
                if let authParams = makeAuthParameters(user: user, key: key) {
                    params["auth"] = authParams
                }

                let requestData = [
                    "id": UUID().uuidString,
                    "method": method,
                    "params": params,
                    "jsonrpc": "2.0"
                ] as [String: Any]

                request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

                let (data, _) = try await URLSession.shared.data(for: request)
                let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

                print("📊 Raw ultra-basic response for method \(method):")
                if let responseData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
                   let responseString = String(data: responseData, encoding: .utf8) {
                    print("📊 \(responseString)")
                }

                if let result = json["result"] as? [String: Any] {
                    print("✅ Ultra-basic method \(method) worked!")
                    print("📊 Result keys: \(Array(result.keys))")
                    return result
                } else if let result = json["result"] as? [[String: Any]] {
                    // Some methods return array directly
                    print("✅ Ultra-basic method \(method) worked (array format)!")
                    print("📊 Array contains \(result.count) items")
                    if let firstItem = result.first {
                        print("📊 First item keys: \(Array(firstItem.keys))")
                    }
                    return ["timetable": result]
                } else if let error = json["error"] as? [String: Any],
                          let code = error["code"] as? Int,
                          code != -32601 {
                    // Method exists but has other error
                    print("⚠️ Method \(method) exists but error: \(error["message"] ?? "unknown")")
                    continue
                }
            } catch {
                continue
            }
        }

        throw NSError(domain: "UntisAPI", code: -32601, userInfo: [
            NSLocalizedDescriptionKey: "No basic timetable methods work on this server"
        ])
    }

    private func attemptGetLessons(
        apiUrl: String,
        id: Int64,
        type: ElementType,
        startDate: Date,
        endDate: Date,
        user: String?,
        key: String?
    ) async throws -> [String: Any] {
        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let lessonsParams: [String: Any] = [
            "id": id,
            "type": type.apiValue,
            "startDate": formatDateInt(startDate),
            "endDate": formatDateInt(endDate),
            "auth": [
                "user": user as Any,
                "key": key as Any
            ]
        ]

        let requestData = [
            "id": UUID().uuidString,
            "method": Self.methodGetLessons,
            "params": [lessonsParams],
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        print("📊 Raw getLessons response:")
        if let responseData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let responseString = String(data: responseData, encoding: .utf8) {
            print("📊 \(responseString.prefix(500))...")
        }

        if let result = json["result"] as? [[String: Any]] {
            print("📊 getLessons returned \(result.count) lesson definitions")

            // Transform lesson definitions into a timetable-like structure
            var transformedLessons: [[String: Any]] = []

            for lesson in result {
                var transformedLesson: [String: Any] = [:]

                // Copy basic fields
                transformedLesson["id"] = lesson["id"]
                transformedLesson["lessonNumber"] = lesson["lessonNumber"]
                transformedLesson["activityType"] = lesson["activityType"]
                transformedLesson["startDate"] = lesson["startDate"]
                transformedLesson["endDate"] = lesson["endDate"]
                transformedLesson["hpw"] = lesson["hpw"] // hours per week
                transformedLesson["studentgroup"] = lesson["studentgroup"]

                // Transform subjects array
                if let subjects = lesson["subjects"] as? [[String: Any]] {
                    transformedLesson["su"] = subjects
                }

                // Transform teachers array
                if let teachers = lesson["teachers"] as? [[String: Any]] {
                    transformedLesson["te"] = teachers
                }

                // Transform classes array (klassen)
                if let klassen = lesson["klassen"] as? [[String: Any]] {
                    transformedLesson["kl"] = klassen
                }

                transformedLessons.append(transformedLesson)
            }

            return [
                "timetable": transformedLessons,
                "masterData": [:],
                "serverMessage": "Using lesson definitions from getLessons method (older WebUntis server)"
            ]
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1
            throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        }
    }

    private func formatDateInt(_ date: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return (year * 10_000) + (month * 100) + day
    }

    private func makeAuthParameters(user: String?, key: String?) -> [String: Any]? {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let username = (user?.isEmpty == false) ? user! : "#anonymous#"
        let otp = generateTotpCode(secret: key, timestamp: timestamp)

        return [
            "user": username,
            "otp": otp,
            "clientTime": timestamp
        ]
    }

    private func generateTotpCode(secret: String?, timestamp: Int64) -> Int {
        guard let secret = secret,
              !secret.isEmpty,
              let keyData = base32Decode(secret) else {
            return 0
        }

        var counter = timestamp / 30_000
        var bigEndianCounter = counter.bigEndian
        let counterData = Data(bytes: &bigEndianCounter, count: MemoryLayout<Int64>.size)

        let symmetricKey = SymmetricKey(data: keyData)
        let authentication = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: symmetricKey)
        let hash = Data(authentication)

        let offset = Int((hash.last ?? 0) & 0x0F)
        guard offset + 3 < hash.count else { return 0 }

        let truncatedHash = (
            (Int(hash[offset]) & 0x7F) << 24 |
            (Int(hash[offset + 1]) & 0xFF) << 16 |
            (Int(hash[offset + 2]) & 0xFF) << 8 |
            (Int(hash[offset + 3]) & 0xFF)
        )

        return truncatedHash % 1_000_000
    }

    private func base32Decode(_ string: String) -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var lookup: [Character: UInt8] = [:]
        for (index, char) in alphabet.enumerated() {
            lookup[char] = UInt8(index)
        }

        let cleaned = string.uppercased().filter { !$0.isWhitespace && $0 != "=" }
        var buffer: UInt32 = 0
        var bitsLeft: Int = 0
        var output = Data()

        for char in cleaned {
            guard let value = lookup[char] else { return nil }
            buffer = (buffer << 5) | UInt32(value)
            bitsLeft += 5

            if bitsLeft >= 8 {
                bitsLeft -= 8
                let byte = UInt8((buffer >> UInt32(bitsLeft)) & 0xFF)
                output.append(byte)
                buffer &= (1 << UInt32(bitsLeft)) - 1
            }
        }

        return output
    }

    func searchSchools(query: String) async throws -> [[String: Any]] {
        struct SchoolSearchAttempt {
            let url: String
            let method: String
            let params: Any
            let transform: (_ json: [String: Any]) -> [[String: Any]]?
        }

        let attempts: [SchoolSearchAttempt] = [
            SchoolSearchAttempt(
                url: Self.defaultSchoolSearchURL,
                method: "searchSchool",
                params: [
                    [
                        "search": query,
                        "maxResults": 50
                    ]
                ],
                transform: { json in
                    if let result = json["result"] as? [String: Any],
                       let schools = result["schools"] as? [[String: Any]] {
                        return schools
                    }
                    return nil
                }
            ),
            SchoolSearchAttempt(
                url: "https://schoolsearch.webuntis.com/schoolquery2",
                method: "searchSchools",
                params: [
                    ["search": query]
                ],
                transform: { json in
                    if let result = json["result"] as? [[String: Any]] {
                        return result
                    }
                    if let result = json["result"] as? [String: Any],
                       let schools = result["schools"] as? [[String: Any]] {
                        return schools
                    }
                    return nil
                }
            )
        ]

        var lastError: NSError?

        for attempt in attempts {
            guard let url = URL(string: attempt.url) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let payload: [String: Any] = [
                "id": UUID().uuidString,
                "method": attempt.method,
                "params": attempt.params,
                "jsonrpc": "2.0"
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    throw NSError(domain: "UntisAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "School search HTTP error: \(httpResponse.statusCode)"])
                }

                let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    let code = error["code"] as? Int ?? -1

                    if attempt.method == "searchSchool" && code == -6003 {
                        throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: "Too many matches. Please refine your school name."])
                    }

                    lastError = NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message])
                    continue
                }

                if let schools = attempt.transform(json) {
                    return schools
                }

            } catch {
                lastError = error as NSError
                continue
            }
        }

        if let error = lastError {
            throw error
        }

        return []
    }

    func getMessagesOfDay(apiUrl: String, date: Date, user: String?, key: String?) async throws -> [[String: Any]] {
        // Try primary method first
        do {
            print("🔄 Trying primary getMessagesOfDay method...")
            return try await attemptGetMessages(
                apiUrl: apiUrl,
                method: Self.methodGetMessagesOfDay,
                date: date,
                user: user,
                key: key,
                useFullParams: true
            )
        } catch {
            if Self.isMethodNotFoundError(error) {
                print("❌ Primary getMessagesOfDay method not found, trying fallbacks...")

                // Try fallback methods
                let fallbackMethods = [
                    Self.methodGetMessagesFallback1,
                    Self.methodGetMessagesFallback2
                ]

                for fallbackMethod in fallbackMethods {
                    do {
                        print("🔄 Trying fallback method: \(fallbackMethod)")
                        return try await attemptGetMessages(
                            apiUrl: apiUrl,
                            method: fallbackMethod,
                            date: date,
                            user: user,
                            key: key,
                            useFullParams: false
                        )
                    } catch {
                        if !Self.isMethodNotFoundError(error) {
                            print("⚠️ Method \(fallbackMethod) exists but has error: \(error.localizedDescription)")
                        }
                        continue
                    }
                }

                // If all fallbacks failed, return empty array instead of failing
                print("⚠️ No message methods supported, returning empty messages")
                return []
            } else {
                throw error
            }
        }
    }

    private func attemptGetMessages(
        apiUrl: String,
        method: String,
        date: Date,
        user: String?,
        key: String?,
        useFullParams: Bool
    ) async throws -> [[String: Any]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Android BetterUntis parameter structure for messages
        var messageParams: [String: Any] = [
            "auth": [
                "user": user as Any,
                "key": key as Any
            ]
        ]

        // Add date parameter for 2017 methods
        if useFullParams {
            messageParams["date"] = dateFormatter.string(from: date)
        }

        let requestData = [
            "id": UUID().uuidString,
            "method": method,
            "params": [messageParams], // Android uses array format
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [[String: Any]] {
            return result
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1
            throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        }
    }

    func getHomeWork(apiUrl: String, startDate: Date, endDate: Date, user: String?, key: String?) async throws -> [[String: Any]] {
        // Try primary method first
        do {
            print("🔄 Trying primary getHomeWork method...")
            return try await attemptGetHomeWork(
                apiUrl: apiUrl,
                method: Self.methodGetHomeWork,
                startDate: startDate,
                endDate: endDate,
                user: user,
                key: key,
                useFullParams: true
            )
        } catch {
            if Self.isMethodNotFoundError(error) {
                print("❌ Primary getHomeWork method not found, trying fallbacks...")

                // Try fallback methods
                let fallbackMethods = [
                    Self.methodGetHomeWorkFallback1,
                    Self.methodGetHomeWorkFallback2
                ]

                for fallbackMethod in fallbackMethods {
                    do {
                        print("🔄 Trying fallback method: \(fallbackMethod)")
                        return try await attemptGetHomeWork(
                            apiUrl: apiUrl,
                            method: fallbackMethod,
                            startDate: startDate,
                            endDate: endDate,
                            user: user,
                            key: key,
                            useFullParams: false
                        )
                    } catch {
                        if !Self.isMethodNotFoundError(error) {
                            print("⚠️ Method \(fallbackMethod) exists but has error: \(error.localizedDescription)")
                        }
                        continue
                    }
                }

                // If all fallbacks failed, return empty array instead of failing
                print("⚠️ No homework methods supported, returning empty homework")
                return []
            } else {
                throw error
            }
        }
    }

    private func attemptGetHomeWork(
        apiUrl: String,
        method: String,
        startDate: Date,
        endDate: Date,
        user: String?,
        key: String?,
        useFullParams: Bool
    ) async throws -> [[String: Any]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Android BetterUntis parameter structure for homework
        var homeworkParams: [String: Any] = [
            "auth": [
                "user": user as Any,
                "key": key as Any
            ]
        ]

        // Add date parameters for 2017 methods
        if useFullParams {
            homeworkParams["startDate"] = dateFormatter.string(from: startDate)
            homeworkParams["endDate"] = dateFormatter.string(from: endDate)
        }

        let requestData = [
            "id": UUID().uuidString,
            "method": method,
            "params": [homeworkParams], // Android uses array format
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [[String: Any]] {
            return result
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1
            throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        }
    }

    func getExams(apiUrl: String, startDate: Date, endDate: Date, user: String?, key: String?) async throws -> [[String: Any]] {
        // Try primary method first
        do {
            print("🔄 Trying primary getExams method...")
            return try await attemptGetExams(
                apiUrl: apiUrl,
                method: Self.methodGetExams,
                startDate: startDate,
                endDate: endDate,
                user: user,
                key: key,
                useFullParams: true
            )
        } catch {
            if Self.isMethodNotFoundError(error) {
                print("❌ Primary getExams method not found, trying fallbacks...")

                // Try fallback methods
                let fallbackMethods = [
                    Self.methodGetExamsFallback1,
                    Self.methodGetExamsFallback2
                ]

                for fallbackMethod in fallbackMethods {
                    do {
                        print("🔄 Trying fallback method: \(fallbackMethod)")
                        return try await attemptGetExams(
                            apiUrl: apiUrl,
                            method: fallbackMethod,
                            startDate: startDate,
                            endDate: endDate,
                            user: user,
                            key: key,
                            useFullParams: false
                        )
                    } catch {
                        if !Self.isMethodNotFoundError(error) {
                            print("⚠️ Method \(fallbackMethod) exists but has error: \(error.localizedDescription)")
                        }
                        continue
                    }
                }

                // If all fallbacks failed, return empty array instead of failing
                print("⚠️ No exam methods supported, returning empty exams")
                return []
            } else {
                throw error
            }
        }
    }

    private func attemptGetExams(
        apiUrl: String,
        method: String,
        startDate: Date,
        endDate: Date,
        user: String?,
        key: String?,
        useFullParams: Bool
    ) async throws -> [[String: Any]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Android BetterUntis parameter structure for exams
        var examsParams: [String: Any] = [
            "auth": [
                "user": user as Any,
                "key": key as Any
            ]
        ]

        // Add date parameters for 2017 methods
        if useFullParams {
            examsParams["startDate"] = dateFormatter.string(from: startDate)
            examsParams["endDate"] = dateFormatter.string(from: endDate)
        }

        let requestData = [
            "id": UUID().uuidString,
            "method": method,
            "params": [examsParams], // Android uses array format
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [[String: Any]] {
            return result
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1
            throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        }
    }

    func getRooms(apiUrl: String, user: String?, key: String?) async throws -> [[String: Any]] {
        // Try primary method first
        do {
            print("🔄 Trying primary getRooms method...")
            return try await attemptGetRooms(
                apiUrl: apiUrl,
                method: Self.methodGetRooms,
                user: user,
                key: key
            )
        } catch {
            if Self.isMethodNotFoundError(error) {
                print("❌ Primary getRooms method not found, trying fallbacks...")

                // Try fallback methods
                let fallbackMethods = [
                    Self.methodGetRoomsFallback1,
                    Self.methodGetRoomsFallback2
                ]

                for fallbackMethod in fallbackMethods {
                    do {
                        print("🔄 Trying fallback method: \(fallbackMethod)")
                        return try await attemptGetRooms(
                            apiUrl: apiUrl,
                            method: fallbackMethod,
                            user: user,
                            key: key
                        )
                    } catch {
                        if !Self.isMethodNotFoundError(error) {
                            print("⚠️ Method \(fallbackMethod) exists but has error: \(error.localizedDescription)")
                        }
                        continue
                    }
                }

                // If all fallbacks failed, return empty array instead of failing
                print("⚠️ No room methods supported, returning empty rooms")
                return []
            } else {
                throw error
            }
        }
    }

    private func attemptGetRooms(
        apiUrl: String,
        method: String,
        user: String?,
        key: String?
    ) async throws -> [[String: Any]] {
        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Android BetterUntis parameter structure for rooms
        let roomsParams: [String: Any] = [
            "auth": [
                "user": user as Any,
                "key": key as Any
            ]
        ]

        let requestData = [
            "id": UUID().uuidString,
            "method": method,
            "params": [roomsParams], // Android uses array format
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [[String: Any]] {
            return result
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1
            throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        }
    }

    func getStudentAbsences(apiUrl: String, startDate: Date, endDate: Date, user: String?, key: String?) async throws -> [[String: Any]] {
        // Try primary method first
        do {
            print("🔄 Trying primary getStudentAbsences method...")
            return try await attemptGetStudentAbsences(
                apiUrl: apiUrl,
                method: Self.methodGetStudentAbsences,
                startDate: startDate,
                endDate: endDate,
                user: user,
                key: key,
                useFullParams: true
            )
        } catch {
            if Self.isMethodNotFoundError(error) {
                print("❌ Primary getStudentAbsences method not found, trying fallbacks...")

                // Try fallback methods
                let fallbackMethods = [
                    Self.methodGetAbsencesFallback1,
                    Self.methodGetAbsencesFallback2
                ]

                for fallbackMethod in fallbackMethods {
                    do {
                        print("🔄 Trying fallback method: \(fallbackMethod)")
                        return try await attemptGetStudentAbsences(
                            apiUrl: apiUrl,
                            method: fallbackMethod,
                            startDate: startDate,
                            endDate: endDate,
                            user: user,
                            key: key,
                            useFullParams: false
                        )
                    } catch {
                        if !Self.isMethodNotFoundError(error) {
                            print("⚠️ Method \(fallbackMethod) exists but has error: \(error.localizedDescription)")
                        }
                        continue
                    }
                }

                // If all fallbacks failed, return empty array instead of failing
                print("⚠️ No absence methods supported, returning empty absences")
                return []
            } else {
                throw error
            }
        }
    }

    private func attemptGetStudentAbsences(
        apiUrl: String,
        method: String,
        startDate: Date,
        endDate: Date,
        user: String?,
        key: String?,
        useFullParams: Bool
    ) async throws -> [[String: Any]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Android BetterUntis parameter structure for absences
        var absencesParams: [String: Any] = [
            "auth": [
                "user": user as Any,
                "key": key as Any
            ]
        ]

        // Add date parameters for 2017 methods
        if useFullParams {
            absencesParams["startDate"] = dateFormatter.string(from: startDate)
            absencesParams["endDate"] = dateFormatter.string(from: endDate)
            absencesParams["includeExcused"] = true
            absencesParams["includeUnExcused"] = true
        }

        let requestData = [
            "id": UUID().uuidString,
            "method": method,
            "params": [absencesParams], // Android uses array format
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [[String: Any]] {
            return result
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1
            throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        }
    }

    // MARK: - Element-based Timetable Methods

    /// Get timetable for a specific element (class, teacher, room, or student)
    func getTimetableForElement(
        apiUrl: String,
        elementId: Int64,
        elementType: ElementType,
        startDate: Date,
        endDate: Date,
        user: String?,
        key: String?
    ) async throws -> [String: Any] {
        // Use the existing getTimetable method but with specified element
        return try await getTimetable(
            apiUrl: apiUrl,
            id: elementId,
            type: elementType,
            startDate: startDate,
            endDate: endDate,
            masterDataTimestamp: 0,
            user: user,
            key: key
        )
    }

    /// Get available classes (for timetable selection)
    func getClasses(apiUrl: String, user: String?, key: String?) async throws -> [[String: Any]] {
        let classesMethods = ["getKlassen", "getClasses", "getAllClasses"]

        for method in classesMethods {
            do {
                print("🔄 Trying method: \(method)")
                return try await attemptGetMasterData(
                    apiUrl: apiUrl,
                    method: method,
                    user: user,
                    key: key
                )
            } catch {
                if !Self.isMethodNotFoundError(error) {
                    print("⚠️ Method \(method) exists but has error: \(error.localizedDescription)")
                }
                continue
            }
        }

        // If no method works, return empty array
        print("⚠️ No class methods supported, returning empty classes")
        return []
    }

    /// Get available teachers (for timetable selection)
    func getTeachers(apiUrl: String, user: String?, key: String?) async throws -> [[String: Any]] {
        let teacherMethods = ["getTeachers", "getAllTeachers", "getTeacherList"]

        for method in teacherMethods {
            do {
                print("🔄 Trying method: \(method)")
                return try await attemptGetMasterData(
                    apiUrl: apiUrl,
                    method: method,
                    user: user,
                    key: key
                )
            } catch {
                if !Self.isMethodNotFoundError(error) {
                    print("⚠️ Method \(method) exists but has error: \(error.localizedDescription)")
                }
                continue
            }
        }

        // If no method works, return empty array
        print("⚠️ No teacher methods supported, returning empty teachers")
        return []
    }

    /// Get available subjects (for timetable selection)
    func getSubjects(apiUrl: String, user: String?, key: String?) async throws -> [[String: Any]] {
        let subjectMethods = ["getSubjects", "getAllSubjects", "getSubjectList"]

        for method in subjectMethods {
            do {
                print("🔄 Trying method: \(method)")
                return try await attemptGetMasterData(
                    apiUrl: apiUrl,
                    method: method,
                    user: user,
                    key: key
                )
            } catch {
                if !Self.isMethodNotFoundError(error) {
                    print("⚠️ Method \(method) exists but has error: \(error.localizedDescription)")
                }
                continue
            }
        }

        // If no method works, return empty array
        print("⚠️ No subject methods supported, returning empty subjects")
        return []
    }

    private func attemptGetMasterData(
        apiUrl: String,
        method: String,
        user: String?,
        key: String?
    ) async throws -> [[String: Any]] {
        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add session cookie if available
        if let sessionCookie = sessionCookie {
            request.setValue("JSESSIONID=\(sessionCookie.value)", forHTTPHeaderField: "Cookie")
        }

        // Use session cookie for authentication instead of auth params
        let masterDataParams: [String: Any] = [:]

        let requestData = [
            "id": UUID().uuidString,
            "method": method,
            "params": [masterDataParams],
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [[String: Any]] {
            return result
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1
            throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        }
    }

    // MARK: - BetterUntis Enhanced Methods

    /// Get student absences with enhanced data structure
    func getStudentAbsencesEnhanced(
        startDate: Date,
        endDate: Date,
        studentId: Int? = nil
    ) async throws -> [StudentAbsence] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let params: [String: Any] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate),
            "studentId": studentId as Any
        ]

        let methods = [
            "getStudentAbsences2017",
            "getStudentAbsences",
            "getAbsences2017",
            "getAbsences"
        ]

        for method in methods {
            do {
                let result = try await makeJSONRPCRequest(
                    method: method,
                    params: params
                )

                if let absencesData = result["result"] as? [[String: Any]] {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)

                        // Try different date formats
                        let formatters = [
                            DateFormatter.untisDateTime,
                            DateFormatter.untisDate,
                            ISO8601DateFormatter()
                        ]

                        for formatter in formatters {
                            if let formatter = formatter as? DateFormatter,
                               let date = formatter.date(from: dateString) {
                                return date
                            } else if let iso8601 = formatter as? ISO8601DateFormatter,
                                      let date = iso8601.date(from: dateString) {
                                return date
                            }
                        }

                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
                    }

                    return try absencesData.compactMap { absenceDict in
                        let data = try JSONSerialization.data(withJSONObject: absenceDict)
                        return try decoder.decode(StudentAbsence.self, from: data)
                    }
                }
                break
            } catch {
                if !Self.isMethodNotFoundError(error) {
                    throw error
                }
                continue
            }
        }

        print("⚠️ No absence methods supported, returning empty absences")
        return []
    }

    /// Create immediate absence entry
    func createImmediateAbsence(
        startDate: Date,
        endDate: Date,
        reasonId: Int? = nil,
        text: String? = nil
    ) async throws -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let params: [String: Any] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate),
            "reasonId": reasonId as Any,
            "text": text as Any
        ]

        let methods = [
            "createImmediateAbsence2017",
            "createImmediateAbsence",
            "createAbsence"
        ]

        for method in methods {
            do {
                let result = try await makeJSONRPCRequest(
                    method: method,
                    params: params
                )

                if let success = result["result"] as? Bool {
                    return success
                } else if let _ = result["result"] {
                    // Some servers return the created absence object
                    return true
                }
                break
            } catch {
                if !Self.isMethodNotFoundError(error) {
                    throw error
                }
                continue
            }
        }

        throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Create absence not supported"])
    }

    /// Delete absence entry
    func deleteAbsence(absenceId: Int) async throws -> Bool {
        let params: [String: Any] = [
            "absenceId": absenceId
        ]

        let methods = [
            "deleteAbsence2017",
            "deleteAbsence",
            "removeAbsence"
        ]

        for method in methods {
            do {
                let result = try await makeJSONRPCRequest(
                    method: method,
                    params: params
                )

                if let success = result["result"] as? Bool {
                    return success
                } else if let _ = result["result"] {
                    return true
                }
                break
            } catch {
                if !Self.isMethodNotFoundError(error) {
                    throw error
                }
                continue
            }
        }

        throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Delete absence not supported"])
    }

    /// Get homework with enhanced data structure
    func getHomeworkEnhanced(
        startDate: Date,
        endDate: Date
    ) async throws -> [HomeWork] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let params: [String: Any] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]

        let methods = [
            "getHomeWork2017",
            "getHomework2017",
            "getHomeWork",
            "getHomework",
            "getAssignments"
        ]

        for method in methods {
            do {
                let result = try await makeJSONRPCRequest(
                    method: method,
                    params: params
                )

                if let homeworkData = result["result"] as? [[String: Any]] {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)

                        let formatters = [
                            DateFormatter.untisDate,
                            DateFormatter.untisDateTime,
                            ISO8601DateFormatter()
                        ]

                        for formatter in formatters {
                            if let formatter = formatter as? DateFormatter,
                               let date = formatter.date(from: dateString) {
                                return date
                            } else if let iso8601 = formatter as? ISO8601DateFormatter,
                                      let date = iso8601.date(from: dateString) {
                                return date
                            }
                        }

                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
                    }

                    return try homeworkData.compactMap { homeworkDict in
                        let data = try JSONSerialization.data(withJSONObject: homeworkDict)
                        return try decoder.decode(HomeWork.self, from: data)
                    }
                }
                break
            } catch {
                if !Self.isMethodNotFoundError(error) {
                    throw error
                }
                continue
            }
        }

        print("⚠️ No homework methods supported, returning empty homework")
        return []
    }

    /// Get exams with enhanced data structure
    func getExamsEnhanced(
        startDate: Date,
        endDate: Date,
        studentId: Int? = nil
    ) async throws -> [EnhancedExam] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let params: [String: Any] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate),
            "studentId": studentId as Any
        ]

        let methods = [
            "getExams2017",
            "getExams",
            "getTests",
            "getExaminations"
        ]

        for method in methods {
            do {
                let result = try await makeJSONRPCRequest(
                    method: method,
                    params: params
                )

                if let examsData = result["result"] as? [[String: Any]] {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)

                        let formatters = [
                            DateFormatter.untisDate,
                            DateFormatter.untisDateTime,
                            ISO8601DateFormatter()
                        ]

                        for formatter in formatters {
                            if let formatter = formatter as? DateFormatter,
                               let date = formatter.date(from: dateString) {
                                return date
                            } else if let iso8601 = formatter as? ISO8601DateFormatter,
                                      let date = iso8601.date(from: dateString) {
                                return date
                            }
                        }

                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
                    }

                    return try examsData.compactMap { examDict in
                        let data = try JSONSerialization.data(withJSONObject: examDict)
                        return try decoder.decode(EnhancedExam.self, from: data)
                    }
                }
                break
            } catch {
                if !Self.isMethodNotFoundError(error) {
                    throw error
                }
                continue
            }
        }

        print("⚠️ No exam methods supported, returning empty exams")
        return []
    }

    /// Post lesson topic (for student interaction)
    func postLessonTopic(
        periodId: Int,
        topic: String,
        homework: String? = nil
    ) async throws -> Bool {
        let params: [String: Any] = [
            "periodId": periodId,
            "topic": topic,
            "homework": homework as Any
        ]

        let methods = [
            "postLessonTopic2017",
            "postLessonTopic",
            "submitLessonTopic",
            "setLessonTopic"
        ]

        for method in methods {
            do {
                let result = try await makeJSONRPCRequest(
                    method: method,
                    params: params
                )

                if let success = result["result"] as? Bool {
                    return success
                } else if let _ = result["result"] {
                    return true
                }
                break
            } catch {
                if !Self.isMethodNotFoundError(error) {
                    throw error
                }
                continue
            }
        }

        throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Post lesson topic not supported"])
    }

    /// Mark absences as checked by parent
    func postAbsencesChecked(absenceIds: [Int]) async throws -> Bool {
        let params: [String: Any] = [
            "absenceIds": absenceIds
        ]

        let methods = [
            "postAbsencesChecked2017",
            "postAbsencesChecked",
            "markAbsencesChecked",
            "acknowledgeAbsences"
        ]

        for method in methods {
            do {
                let result = try await makeJSONRPCRequest(
                    method: method,
                    params: params
                )

                if let success = result["result"] as? Bool {
                    return success
                } else if let _ = result["result"] {
                    return true
                }
                break
            } catch {
                if !Self.isMethodNotFoundError(error) {
                    throw error
                }
                continue
            }
        }

        throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Check absences not supported"])
    }

    /// Get period data with enhanced information
    func getPeriodDataEnhanced(
        elementType: Int,
        elementId: Int,
        startDate: Date,
        endDate: Date
    ) async throws -> [PeriodData] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let params: [String: Any] = [
            "elementType": elementType,
            "elementId": elementId,
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]

        let methods = [
            "getPeriodData2017",
            "getPeriodData",
            "getTimetableDataWithStatus"
        ]

        for method in methods {
            do {
                let result = try await makeJSONRPCRequest(
                    method: method,
                    params: params
                )

                if let periodData = result["result"] as? [[String: Any]] {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)

                        let formatters = [
                            DateFormatter.untisDate,
                            DateFormatter.untisDateTime,
                            ISO8601DateFormatter()
                        ]

                        for formatter in formatters {
                            if let formatter = formatter as? DateFormatter,
                               let date = formatter.date(from: dateString) {
                                return date
                            } else if let iso8601 = formatter as? ISO8601DateFormatter,
                                      let date = iso8601.date(from: dateString) {
                                return date
                            }
                        }

                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
                    }

                    return try periodData.compactMap { periodDict in
                        let data = try JSONSerialization.data(withJSONObject: periodDict)
                        return try decoder.decode(PeriodData.self, from: data)
                    }
                }
                break
            } catch {
                if !Self.isMethodNotFoundError(error) {
                    throw error
                }
                continue
            }
        }

        print("⚠️ No enhanced period data methods supported, returning empty periods")
        return []
    }

    // MARK: - Helper Methods for BetterUntis

    /// Test if BetterUntis enhanced methods are available
    func testBetterUntisSupport() async -> [String: Bool] {
        var results: [String: Bool] = [:]

        let testMethods = [
            "getStudentAbsences2017",
            "createImmediateAbsence2017",
            "deleteAbsence2017",
            "getHomeWork2017",
            "getExams2017",
            "postLessonTopic2017",
            "postAbsencesChecked2017",
            "getPeriodData2017"
        ]

        for method in testMethods {
            do {
                // Try to call method with minimal params to test availability
                let _ = try await makeJSONRPCRequest(method: method, params: [String: Any]())
                results[method] = true
            } catch {
                results[method] = !Self.isMethodNotFoundError(error)
            }
        }

        return results
    }

    // MARK: - Helper Methods

    /// Helper method to make JSONRPC requests using session cookies
    private func makeJSONRPCRequest(method: String, params: [String: Any]) async throws -> [String: Any] {
        guard let sessionCookie = sessionCookie, let baseURL = baseURL else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated or no session available"])
        }

        // Construct the full API URL for this request
        let url = URL(string: baseURL + "/jsonrpc.do")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        // Add session cookie
        request.setValue("JSESSIONID=\(sessionCookie.value)", forHTTPHeaderField: "Cookie")

        // Build JSONRPC request
        let requestData = [
            "id": UUID().uuidString,
            "method": method,
            "params": params,
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        // Log the request
        print("🌐 JSONRPC Request: \(method) with \(params.keys.count) parameters")

        let (data, response) = try await URLSession.shared.data(for: request)

        // Log the response
        if let httpResponse = response as? HTTPURLResponse {
            print("✅ \(httpResponse.statusCode) \(url) (\(String(format: "%.2f", 0.0))s) [\(data.count) bytes]")
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1
            throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: message])
        }

        return json
    }
}
