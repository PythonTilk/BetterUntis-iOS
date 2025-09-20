import Foundation

class UntisAPIClient {
    // MARK: - Constants
    static let defaultSchoolSearchURL = "https://mobile.webuntis.com/ms/schoolquery2"

    // Platform Application Identifiers
    static let applicationId = "BetterUntis-iOS"
    static let applicationVersion = "1.0.0"
    static let platformIdentifier = "iOS"
    static let clientName = "BetterUntis for iOS"
    static let developerId = "BetterUntis-Platform"
    static let userAgent = "BetterUntis/1.0.0 (iOS; iPhone; Mobile)"

    // API Methods
    static let methodCreateImmediateAbsence = "createImmediateAbsence2017"
    static let methodDeleteAbsence = "deleteAbsence2017"
    static let methodAuthenticate = "authenticate"
    static let methodGetAuthToken = "authenticate"
    static let methodGetAppSharedSecret = "getAppSharedSecret"
    static let methodAuthenticateWithSecret = "authenticate"
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
        client: String = "BetterUntis"
    ) async throws -> String {
        print("🔄 UntisAPIClient.authenticate - URL: \(apiUrl)")
        print("🔄 UntisAPIClient.authenticate - User: \(user)")

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
            "method": Self.methodAuthenticate,
            "params": [
                "user": user,
                "password": password,
                "client": Self.clientName,
                "applicationId": Self.applicationId,
                "platformId": Self.platformIdentifier,
                "version": Self.applicationVersion
            ],
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, response) = try await URLSession.shared.data(for: request)

        // Debug response
        if let responseString = String(data: data, encoding: .utf8) {
            print("Authentication response: \(responseString)")
        }

        if let httpResponse = response as? HTTPURLResponse {
            print("HTTP Status: \(httpResponse.statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [String: Any],
           let sessionId = result["sessionId"] as? String {
            return sessionId
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

            throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: userFriendlyMessage])
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown authentication error"])
        }
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Android BetterUntis parameter structure - params as array with single object
        var timetableParams: [String: Any] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate),
            "auth": [
                "user": user as Any,
                "key": key as Any
            ]
        ]

        // Add additional parameters for 2017 methods (Android format)
        if useFullParams {
            timetableParams["id"] = id
            timetableParams["type"] = type.rawValue
            timetableParams["masterDataTimestamp"] = masterDataTimestamp
            timetableParams["timetableTimestamp"] = 0
            timetableParams["timetableTimestamps"] = []
        }

        let requestData = [
            "id": UUID().uuidString,
            "method": method,
            "params": [timetableParams], // Android uses array format
            "jsonrpc": "2.0"
        ] as [String: Any]

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

                // Minimal parameters - just authentication
                let requestData = [
                    "id": UUID().uuidString,
                    "method": method,
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        let url = URL(string: apiUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let lessonsParams: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate),
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

    func searchSchools(query: String) async throws -> [[String: Any]] {
        // Based on debugging: API expects params as array of JSONObjects
        // Error shows: "class java.lang.String cannot be cast to class net.minidev.json.JSONObject"
        // Correct format: params: [{"search": "query"}]

        let searchURL = "https://schoolsearch.webuntis.com/schoolquery2"

        var request = URLRequest(url: URL(string: searchURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestData = [
            "id": UUID().uuidString,
            "method": "searchSchools",
            "params": [
                ["search": query] // Fixed: Array containing object instead of object directly
            ],
            "jsonrpc": "2.0"
        ] as [String: Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, response) = try await URLSession.shared.data(for: request)

        // Debug: Print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("School search response: \(responseString)")
        }

        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                throw NSError(domain: "UntisAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
            }
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let result = json["result"] as? [String: Any],
           let schools = result["schools"] as? [[String: Any]] {
            return schools
        } else if let result = json["result"] as? [[String: Any]] {
            // Some APIs return schools directly as array
            return result
        } else if let error = json["error"] as? [String: Any],
                  let message = error["message"] as? String {
            let code = error["code"] as? Int ?? -1

            // Provide more helpful error messages based on debugging
            if code == -6001 || message.contains("invalid method") {
                throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: "School search is currently not available. The API method may have been deprecated."])
            } else if message.contains("JSONObject") || message.contains("cast") {
                throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: "School search parameter format error. Please try again."])
            } else {
                throw NSError(domain: "UntisAPI", code: code, userInfo: [NSLocalizedDescriptionKey: "School search failed: \(message)"])
            }
        } else {
            throw NSError(domain: "UntisAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No schools found or invalid response format"])
        }
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

        let masterDataParams: [String: Any] = [
            "auth": [
                "user": user as Any,
                "key": key as Any
            ]
        ]

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
                    params: [params]
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
                    params: [params]
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
                    params: [params]
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
                    params: [params]
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
                    params: [params]
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
                    params: [params]
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
                    params: [params]
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
                    params: [params]
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
                let _ = try await makeJSONRPCRequest(method: method, params: [[String: Any]()])
                results[method] = true
            } catch {
                results[method] = !Self.isMethodNotFoundError(error)
            }
        }

        return results
    }
}