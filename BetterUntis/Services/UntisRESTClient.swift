import Foundation
import Combine

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
                DateFormatter.untisDateTimeMinutes,
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
        let encodedSchool = schoolName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? schoolName
        let endpoint = "/WebUntis/api/mobile/v2/\(encodedSchool)/authentication"
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
            await storeToken(authResponse.accessToken)

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
        let encodedSchool = schoolName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? schoolName
        let endpoint = "/WebUntis/api/mobile/v2/\(encodedSchool)/authentication/refresh"
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
        await storeToken(authResponse.accessToken)

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

        let startOfDay = Calendar.current.startOfDay(for: startDate)
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let startDateStr = DateFormatter.untisDateTime.string(from: startOfDay)
        let endDateStr = DateFormatter.untisDateTime.string(from: endOfDay)

        var components = URLComponents(string: baseURL + "/WebUntis/api/rest/extern/v3/timetable")!
        var queryItems = [
            URLQueryItem(name: "start", value: startDateStr),
            URLQueryItem(name: "end", value: endDateStr),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        switch elementType {
        case .klasse:
            queryItems.append(URLQueryItem(name: "class", value: String(elementId)))
        case .teacher:
            queryItems.append(URLQueryItem(name: "teacher", value: String(elementId)))
        case .subject:
            queryItems.append(URLQueryItem(name: "subject", value: String(elementId)))
        case .room:
            queryItems.append(URLQueryItem(name: "room", value: String(elementId)))
        case .student:
            queryItems.append(URLQueryItem(name: "student", value: String(elementId)))
        }

        components.queryItems = queryItems

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

    /// Retrieve timetable entries using the modern view/v1 endpoint
    func getTimetableEntries(
        resourceType: RESTElementType,
        resourceIds: [Int],
        startDate: Date,
        endDate: Date,
        cacheMode: RESTCacheMode = .offlineOnly,
        format: Int? = nil,
        periodTypes: [String]? = nil,
        timetableType: RESTTimetableType? = nil,
        layout: RESTTimetableLayout = .priority
    ) async throws -> TimetableEntriesResponse {

        guard let token = authToken else {
            throw UntisAPIError(code: 401, message: "Not authenticated", details: "No auth token available", timestamp: Date())
        }

        let startOfDay = Calendar.current.startOfDay(for: startDate)
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let startString = DateFormatter.untisDateTime.string(from: startOfDay)
        let endString = DateFormatter.untisDateTime.string(from: endOfDay)

        var components = URLComponents(string: baseURL + "/WebUntis/api/rest/view/v1/timetable/entries")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "start", value: startString),
            URLQueryItem(name: "end", value: endString),
            URLQueryItem(name: "resourceType", value: resourceType.rawValue),
            URLQueryItem(name: "layout", value: layout.rawValue)
        ]

        if let format = format {
            queryItems.append(URLQueryItem(name: "format", value: String(format)))
        }

        for resourceId in resourceIds {
            queryItems.append(URLQueryItem(name: "resources", value: String(resourceId)))
        }

        if let periodTypes, !periodTypes.isEmpty {
            queryItems.append(URLQueryItem(name: "periodTypes", value: periodTypes.joined(separator: ",")))
        }

        if let timetableType {
            queryItems.append(URLQueryItem(name: "timetableType", value: timetableType.rawValue))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw UntisAPIError(code: 400, message: "Failed to build timetable entries URL", details: nil, timestamp: Date())
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(cacheMode.rawValue, forHTTPHeaderField: "Cache-Mode")

        print("📅 REST Timetable entries request: \(url)")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📅 REST Timetable entries status: \(httpResponse.statusCode)")

                guard httpResponse.statusCode == 200 else {
                    if let errorData = try? jsonDecoder.decode(UntisAPIError.self, from: data) {
                        throw errorData
                    }
                    throw UntisAPIError(code: httpResponse.statusCode, message: "Timetable entries request failed", details: nil, timestamp: Date())
                }
            }

            let entriesResponse = try jsonDecoder.decode(TimetableEntriesResponse.self, from: data)
            print("✅ REST Timetable entries received for \(entriesResponse.days.count) day(s)")
            return entriesResponse
        } catch {
            print("❌ REST Timetable entries failed: \(error)")
            lastError = error
            throw error
        }
    }

    /// Retrieve available rooms using the room finder endpoint
    func getAvailableRooms(
        startDateTime: Date,
        endDateTime: Date,
        cacheMode: RESTCacheMode = .offlineOnly
    ) async throws -> CalendarPeriodRoomResponse {

        guard let token = authToken else {
            throw UntisAPIError(code: 401, message: "Not authenticated", details: "No auth token available", timestamp: Date())
        }

        let startString = DateFormatter.untisDateTime.string(from: startDateTime)
        let endString = DateFormatter.untisDateTime.string(from: endDateTime)

        var components = URLComponents(string: baseURL + "/WebUntis/api/rest/view/v1/calendar-entry/rooms/form")!
        components.queryItems = [
            URLQueryItem(name: "startDateTime", value: startString),
            URLQueryItem(name: "endDateTime", value: endString)
        ]

        guard let url = components.url else {
            throw UntisAPIError(code: 400, message: "Failed to build room finder URL", details: nil, timestamp: Date())
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(cacheMode.rawValue, forHTTPHeaderField: "Cache-Mode")

        print("🏫 REST Room finder request: \(url)")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("🏫 REST Room finder status: \(httpResponse.statusCode)")

                guard httpResponse.statusCode == 200 else {
                    if let errorData = try? jsonDecoder.decode(UntisAPIError.self, from: data) {
                        throw errorData
                    }
                    throw UntisAPIError(code: httpResponse.statusCode, message: "Room finder request failed", details: nil, timestamp: Date())
                }
            }

            let roomsResponse = try jsonDecoder.decode(CalendarPeriodRoomResponse.self, from: data)
            print("✅ REST Room finder returned \(roomsResponse.rooms.count) rooms")
            return roomsResponse
        } catch {
            print("❌ REST Room finder failed: \(error)")
            lastError = error
            throw error
        }
    }

    /// Fetch student absences via the SAA REST API
    func getStudentAbsences(request payload: SaaDataRequest) async throws -> SaaDataResponse {
        guard let token = authToken else {
            throw UntisAPIError(code: 401, message: "Not authenticated", details: "No auth token available", timestamp: Date())
        }

        let url = URL(string: baseURL + "/WebUntis/api/rest/view/v4/classreg/absences")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try jsonEncoder.encode(payload)

        print("🚨 REST SAA absences request: \(url)")

        do {
            let (data, response) = try await session.data(for: urlRequest)

            if let httpResponse = response as? HTTPURLResponse {
                print("🚨 REST SAA absences status: \(httpResponse.statusCode)")

                guard httpResponse.statusCode == 200 else {
                    if let errorData = try? jsonDecoder.decode(UntisAPIError.self, from: data) {
                        throw errorData
                    }
                    throw UntisAPIError(code: httpResponse.statusCode, message: "Absence request failed", details: nil, timestamp: Date())
                }
            }

            let decodedResponse = try jsonDecoder.decode(SaaDataResponse.self, from: data)
            print("✅ REST SAA absences returned \(decodedResponse.absences.count) entries")
            return decodedResponse
        } catch {
            print("❌ REST SAA absences failed: \(error)")
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

        let url = URL(string: baseURL + "/WebUntis/api/rest/view/v1/mobile/data")!

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
        if let token = keychain.loadString(forKey: "untis_rest_token_\(schoolName)") {
            authToken = token
            isAuthenticated = true
            print("🔑 Loaded stored REST token for \(schoolName)")
        }
    }

    private func storeToken(_ token: String) async {
        authToken = token
        isAuthenticated = true
        keychain.save(string: token, forKey: "untis_rest_token_\(schoolName)")
        print("🔑 Stored REST token for \(schoolName)")
    }

    func clearToken() {
        authToken = nil
        isAuthenticated = false
        keychain.deleteString(forKey: "untis_rest_token_\(schoolName)")
        print("🔑 Cleared REST token for \(schoolName)")
    }

    // MARK: - Utility Methods

    /// Test connection to the REST API
    func testConnection() async -> Bool {
        let url = URL(string: baseURL + "/WebUntis/api/rest/extern/v3/timetable")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "OPTIONS"
        urlRequest.timeoutInterval = 10

        do {
            let (_, response) = try await session.data(for: urlRequest)
            if let httpResponse = response as? HTTPURLResponse {
                if (401...403).contains(httpResponse.statusCode) {
                    return true
                }
                return httpResponse.statusCode < 500
            }
            return false
        } catch {
            print("❌ REST connection test failed: \(error)")
            return false
        }
    }

    /// Convert TimetableElement to Period for compatibility
    func convertTimetableToPeriods(_ elements: [TimetableElement]) -> [Period] {
        return elements.compactMap { element -> Period? in
            // Parse the date and time information
            guard let dateStr = element.date.split(separator: "T").first else { return nil }
            guard let baseDate = DateFormatter.untisDate.date(from: String(dateStr)) else { return nil }

            // Create start and end datetime
            guard let startTime = Int(element.startTime) else { return nil }
            guard let endTime = Int(element.endTime) else { return nil }

            let startDateTime = Calendar.current.date(bySettingHour: startTime / 100, minute: startTime % 100, second: 0, of: baseDate) ?? baseDate
            let endDateTime = Calendar.current.date(bySettingHour: endTime / 100, minute: endTime % 100, second: 0, of: baseDate) ?? baseDate

            // Create period elements
            var periodElements: [PeriodElement] = []

            if let teachers = element.te {
                periodElements.append(contentsOf: teachers.map { teacher in
                    PeriodElement(type: .teacher, id: Int64(teacher.id), name: teacher.name ?? "", longName: teacher.longname ?? teacher.name ?? "", displayName: nil, alternateName: nil, backColor: nil, foreColor: nil, canViewTimetable: nil)
                })
            }

            if let rooms = element.ro {
                periodElements.append(contentsOf: rooms.map { room in
                    PeriodElement(type: .room, id: Int64(room.id), name: room.name ?? "", longName: room.longname ?? room.name ?? "", displayName: nil, alternateName: nil, backColor: nil, foreColor: nil, canViewTimetable: nil)
                })
            }

            if let subjects = element.su {
                periodElements.append(contentsOf: subjects.map { subject in
                    PeriodElement(type: .subject, id: Int64(subject.id), name: subject.name ?? "", longName: subject.longname ?? subject.name ?? "", displayName: nil, alternateName: nil, backColor: nil, foreColor: nil, canViewTimetable: nil)
                })
            }

            // Create period text
            let periodText = PeriodText(
                lesson: element.su?.first?.name ?? element.su?.first?.longname,
                substitution: element.bkText,
                info: element.info
            )

            return Period(
                id: Int64(element.id),
                lessonId: Int64(element.id), // Use same as ID
                startDateTime: startDateTime,
                endDateTime: endDateTime,
                foreColor: "#000000",
                backColor: "#FFFFFF",
                innerForeColor: "#000000",
                innerBackColor: "#FFFFFF",
                text: periodText,
                elements: periodElements,
                can: [],
                is: [],
                homeWorks: nil,
                exam: nil,
                isOnlinePeriod: false,
                messengerChannel: nil,
                onlinePeriodLink: nil,
                blockHash: nil
            )
        }
    }

    /// Convert timetable entries response (view/v1) into domain periods
    func convertTimetableEntriesToPeriods(
        _ response: TimetableEntriesResponse,
        resourceType: RESTElementType,
        primaryResourceId: Int?
    ) -> [Period] {
        var periods: [Period] = []
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTime, .withDashSeparatorInDate]

        func parseDateTime(_ string: String?) -> Date? {
            guard let string else { return nil }
            if let date = DateFormatter.untisDateTime.date(from: string) {
                return date
            }
            if let date = DateFormatter.untisDateTimeMinutes.date(from: string) {
                return date
            }
            return isoFormatter.date(from: string)
        }

        func parseDuration(_ duration: TimetableDuration?) -> (Date, Date)? {
            guard let duration,
                  let start = parseDateTime(duration.start),
                  let end = parseDateTime(duration.end) else { return nil }
            return (start, end)
        }

        func elementType(for restType: RESTElementType) -> ElementType {
            switch restType {
            case .klasse: return .klasse
            case .teacher: return .teacher
            case .subject: return .subject
            case .room: return .room
            case .student: return .student
            }
        }

        func makeElement(from summary: TimetableResourceSummary?, restTypeString: String?, fallbackType: RESTElementType, fallbackId: Int?) -> PeriodElement? {
            if let summary,
               let id = summary.id,
               let restTypeString,
               let type = ElementType(restType: restTypeString) {
                let baseName = summary.shortName ?? summary.longName ?? summary.displayName ?? "#\(id)"
                let longName = summary.longName ?? summary.displayName ?? baseName
                return PeriodElement(
                    type: type,
                    id: Int64(id),
                    name: baseName,
                    longName: longName,
                    displayName: summary.displayName ?? longName,
                    alternateName: summary.shortName,
                    backColor: nil,
                    foreColor: nil,
                    canViewTimetable: nil
                )
            }

            if let fallbackId,
               fallbackId > 0 {
                let type = elementType(for: fallbackType)
                let baseName = "#\(fallbackId)"
                return PeriodElement(
                    type: type,
                    id: Int64(fallbackId),
                    name: baseName,
                    longName: baseName,
                    displayName: nil,
                    alternateName: nil,
                    backColor: nil,
                    foreColor: nil,
                    canViewTimetable: nil
                )
            }

            return nil
        }

        func makeElements(from entry: TimetableGridEntry, baseElement: PeriodElement?) -> [PeriodElement] {
            var elements: [PeriodElement] = []
            var seen = Set<String>()

            if let baseElement {
                elements.append(baseElement)
                seen.insert("\(baseElement.type.rawValue)-\(baseElement.id)")
            }

            let positionBuckets: [[TimetablePositionItem]?] = [entry.position1, entry.position2, entry.position3, entry.position4, entry.position5]

            for bucket in positionBuckets {
                guard let bucket else { continue }
                for item in bucket {
                    guard let content = item.current ?? item.original,
                          let typeString = content.type,
                          let type = ElementType(restType: typeString),
                          let identifier = content.id else {
                        continue
                    }

                    let key = "\(type.rawValue)-\(identifier)"
                    if seen.contains(key) { continue }

                    let longName = content.text ?? content.shortText ?? "#\(identifier)"
                    let name = content.shortText ?? content.text ?? longName

                    elements.append(
                        PeriodElement(
                            type: type,
                            id: Int64(identifier),
                            name: name,
                            longName: longName,
                            displayName: content.text ?? longName,
                            alternateName: content.shortText,
                            backColor: content.backColor,
                            foreColor: content.foreColor,
                            canViewTimetable: nil
                        )
                    )
                    seen.insert(key)
                }
            }

            if elements.isEmpty, let baseElement {
                elements.append(baseElement)
            }

            return elements
        }

        func mapStatus(_ status: String?) -> [PeriodState] {
            guard let status else { return [] }
            switch status.uppercased() {
            case "CANCELLED": return [.cancelled]
            case "EXAM": return [.exam]
            case "IRREGULAR": return [.irregular]
            case "SUBSTITUTION": return [.teacherSubstitution]
            case "REGULAR": return [.regular]
            default: return []
            }
        }

        func makePeriod(
            id: Int64,
            start: Date,
            end: Date,
            text: PeriodText,
            elements: [PeriodElement],
            status: String?,
            statusDetail: String?,
            color: String?,
            layoutGroup: Int?
        ) -> Period {
            let states = mapStatus(status)
            let backColor = color ?? "#FFFFFF"
            return Period(
                id: id,
                lessonId: id,
                startDateTime: start,
                endDateTime: end,
                foreColor: "#000000",
                backColor: backColor,
                innerForeColor: "#000000",
                innerBackColor: backColor,
                text: text,
                elements: elements,
                can: [],
                is: states,
                homeWorks: nil,
                exam: nil,
                isOnlinePeriod: nil,
                messengerChannel: nil,
                onlinePeriodLink: nil,
                blockHash: layoutGroup
            )
        }

        let fallbackId = primaryResourceId

        response.days.forEach { day in
            let dayElement = makeElement(from: day.resource, restTypeString: day.resourceType, fallbackType: resourceType, fallbackId: fallbackId)

            day.gridEntries.enumerated().forEach { index, entry in
                guard let (start, end) = parseDuration(entry.duration) else { return }

                let periodId = Int64(entry.ids?.first ?? Int(start.timeIntervalSince1970) + index)
                let elements = makeElements(from: entry, baseElement: dayElement)

                let periodText = PeriodText(
                    lesson: entry.name,
                    substitution: entry.statusDetail,
                    info: entry.notesAll
                )

                let period = makePeriod(
                    id: periodId,
                    start: start,
                    end: end,
                    text: periodText,
                    elements: elements,
                    status: entry.status,
                    statusDetail: entry.statusDetail,
                    color: entry.color,
                    layoutGroup: entry.layoutGroup
                )

                periods.append(period)
            }

            day.dayEntries.enumerated().forEach { index, entry in
                guard let (start, end) = parseDuration(entry.duration) else { return }
                let periodId = Int64(entry.ids?.first ?? Int(start.timeIntervalSince1970) + index + 10_000)

                let periodText = PeriodText(
                    lesson: entry.name ?? entry.information?.title,
                    substitution: entry.statusDetail ?? entry.information?.text,
                    info: entry.notesAll ?? entry.information?.text
                )

                let elements = dayElement.map { [$0] } ?? []

                let period = makePeriod(
                    id: periodId,
                    start: start,
                    end: end,
                    text: periodText,
                    elements: elements,
                    status: entry.status,
                    statusDetail: entry.statusDetail,
                    color: nil,
                    layoutGroup: nil
                )

                periods.append(period)
            }
        }

        return periods.sorted { $0.startDateTime < $1.startDateTime }
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
