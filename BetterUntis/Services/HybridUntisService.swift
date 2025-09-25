import Foundation
import Combine

/// Hybrid service that combines REST API, JSONRPC API, and HTML parsing fallback
@MainActor
class HybridUntisService: ObservableObject {

    // MARK: - Properties

    private let restClient: UntisRESTClient
    private let jsonrpcClient: UntisAPIClient
    private var htmlParser: WebUntisHTMLParser?
    private let keychain: KeychainManager

    @Published var isAuthenticated = false
    @Published var currentAuthMethod: AuthMethod = .none
    @Published var serverCapabilities: ServerCapabilities?
    @Published var lastError: Error?

    // Server details
    private var serverURL: String = ""
    private var schoolName: String = ""
    private var cachedCredentials: (username: String, password: String)?

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
        var supportsRESTAPI: Bool
        var supportsJSONRPC: Bool
        var supportedJSONRPCMethods: [String]
        var supportsHTMLParsing: Bool
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

    init(
        baseURL: String,
        schoolName: String,
        restClient: UntisRESTClient,
        jsonrpcClient: UntisAPIClient,
        keychain: KeychainManager
    ) {
        self.restClient = restClient
        self.jsonrpcClient = jsonrpcClient
        self.keychain = keychain
        self.serverURL = baseURL
        self.schoolName = schoolName

        // Load cached capabilities
        loadServerCapabilities(for: "\(baseURL)_\(schoolName)")
    }

    convenience init(
        baseURL: String,
        schoolName: String
    ) {
        self.init(
            baseURL: baseURL,
            schoolName: schoolName,
            restClient: UntisRESTClient.create(for: baseURL, schoolName: schoolName),
            jsonrpcClient: UntisAPIClient(),
            keychain: KeychainManager.shared
        )
    }

    // MARK: - Authentication

    /// Authenticate using the best available method
    func authenticate(username: String, password: String, serverURL: String, schoolName: String) async throws {
        print("🔐 Starting hybrid authentication...")

        // Store server details for later use
        self.serverURL = serverURL
        self.schoolName = schoolName
        self.cachedCredentials = (username, password)

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
                        restClient.updateTokenScope(userIdentifier: username)
                        let _ = try await restClient.authenticate(username: username, password: password)
                        isAuthenticated = true
                        currentAuthMethod = .rest
                        print("✅ Authenticated via REST API")
                        return
                    }

                case .jsonrpc:
                    if enableJSONRPC && serverCapabilities?.supportsJSONRPC == true {
                        // Use the same URL building logic as capability testing
                        let fullApiUrl = WebUntisURLParser.buildJsonRpcApiUrl(server: serverURL, school: schoolName)
                        let authResult = try await jsonrpcClient.authenticate(
                            apiUrl: fullApiUrl,
                            user: username,
                            password: password
                        )
                        print("✅ JSONRPC session established (id: \(authResult.sessionId.prefix(8)))")
                        isAuthenticated = true
                        currentAuthMethod = .jsonrpc
                        print("✅ Authenticated via JSONRPC")
                        return
                    }

                case .html:
                    if enableHTMLParsing && serverCapabilities?.supportsHTMLParsing == true {
                        _ = try await ensureHTMLSession(username: username, password: password)
                        isAuthenticated = true
                        currentAuthMethod = .html
                        print("✅ Authenticated via HTML parser fallback")
                        return
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

        // If all methods failed, provide contextual error message
        if serverCapabilities?.supportsHTMLParsing == true &&
           !serverCapabilities!.supportsRESTAPI &&
           !serverCapabilities!.supportsJSONRPC {
            let errorMessage = authErrors[.html]?.localizedDescription ?? "HTML authentication failed"
            lastError = NSError(domain: "HybridAuth", code: -2, userInfo: [
                NSLocalizedDescriptionKey: errorMessage
            ])
        } else {
            // Standard authentication failure
            let errorMessage = authErrors.map { "\($0.key.rawValue): \($0.value.localizedDescription)" }.joined(separator: ", ")
            lastError = NSError(domain: "HybridAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "All authentication methods failed: \(errorMessage)"])
        }
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

        if enableRESTAPI && restClient.isAuthenticated {
            do {
                let restElementType: RESTElementType
                switch elementType {
                case .klasse: restElementType = .klasse
                case .teacher: restElementType = .teacher
                case .subject: restElementType = .subject
                case .room: restElementType = .room
                case .student: restElementType = .student
                }

                let cacheMode: RESTCacheMode = preferRESTAPI ? .noCache : .offlineOnly
                let response = try await restClient.getTimetableEntries(
                    resourceType: restElementType,
                    resourceIds: [elementId],
                    startDate: startDate,
                    endDate: endDate,
                    cacheMode: cacheMode,
                    format: 1,
                    periodTypes: nil,
                    timetableType: .myTimetable,
                    layout: .priority
                )

                let periods = restClient.convertTimetableEntriesToPeriods(
                    response,
                    resourceType: restElementType,
                    primaryResourceId: elementId
                )
                print("📅 Retrieved \(periods.count) periods via REST timetable entries")
                return periods
            } catch {
                print("⚠️ REST timetable failed, attempting other fallbacks: \(error.localizedDescription)")

                // Check if authentication expired
                if let apiError = error as? UntisAPIError, apiError.code == 401 {
                    isAuthenticated = false
                    currentAuthMethod = .none
                }

                lastError = error
            }
        }

        if enableJSONRPC && jsonrpcClient.isAuthenticated {
            do {
                let fullApiUrl = WebUntisURLParser.buildJsonRpcApiUrl(server: serverURL, school: schoolName)
                let timetableData = try await jsonrpcClient.getTimetable(
                    apiUrl: fullApiUrl,
                    id: Int64(elementId),
                    type: elementType,
                    startDate: startDate,
                    endDate: endDate,
                    masterDataTimestamp: 0,
                    user: nil,
                    key: nil
                )

                if let periods = TimetableTransformer.fromJSONRPC(timetableData: timetableData) {
                    print("📅 Retrieved \(periods.count) periods via JSONRPC")
                    return periods
                }
                throw NSError(domain: "HybridService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to convert JSONRPC timetable"])
            } catch {
                print("⚠️ JSONRPC timetable failed, falling back to HTML: \(error.localizedDescription)")
                lastError = error
            }
        }

        if enableHTMLParsing {
            do {
                let parser = try await ensureHTMLSession()
                let htmlPeriods = try await parser.parseEnhancedTimetable(startDate: startDate, endDate: endDate)
                let periods = convertHTMLPeriods(htmlPeriods)
                print("📅 Retrieved \(periods.count) periods via HTML parser")
                return periods
            } catch {
                print("❌ HTML timetable parsing failed: \(error.localizedDescription)")
                lastError = error
            }
        }

        throw lastError ?? NSError(domain: "HybridService", code: -1, userInfo: [NSLocalizedDescriptionKey: "All timetable methods failed"])
    }

    /// Get student absences using the best available method
    func getStudentAbsences(startDate: Date, endDate: Date) async throws -> [StudentAbsence] {
        guard isAuthenticated else {
            throw NSError(domain: "HybridService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        var lastError: Error?

        if enableRESTAPI && restClient.isAuthenticated {
            do {
                let requestPayload = SaaDataRequest(
                    classId: nil,
                    dateRange: SaaDateRange(
                        start: DateFormatter.untisDateTime.string(from: Calendar.current.startOfDay(for: startDate)),
                        end: DateFormatter.untisDateTime.string(from: Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate)
                    ),
                    dateRangeType: nil,
                    studentId: nil,
                    studentGroupId: nil,
                    excuseStatusType: nil,
                    filterForMissingLGNotifications: nil
                )

                let response = try await restClient.getStudentAbsences(request: requestPayload)
                let absences = convertSaaAbsences(response)
                print("🏥 Retrieved \(absences.count) absences via REST API")
                return absences
            } catch {
                print("⚠️ REST absences failed, trying other methods: \(error.localizedDescription)")
                lastError = error
            }
        }

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

        if enableHTMLParsing {
            do {
                let parser = try await ensureHTMLSession()
                let htmlAbsences = try await parser.parseAbsences()
                let absences = convertHTMLAbsences(htmlAbsences)
                print("🏥 Retrieved \(absences.count) absences via HTML parser")
                return absences
            } catch {
                print("❌ HTML absence parsing failed: \(error.localizedDescription)")
                lastError = error
            }
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

        if enableHTMLParsing {
            do {
                let parser = try await ensureHTMLSession()
                let htmlHomework = try await parser.parseHomework(startDate: startDate, endDate: endDate)
                let homework = convertHTMLHomework(htmlHomework)
                print("📚 Retrieved \(homework.count) homework items via HTML parser")
                return homework
            } catch {
                print("❌ HTML homework parsing failed: \(error.localizedDescription)")
                lastError = error
            }
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

        if enableHTMLParsing {
            do {
                let parser = try await ensureHTMLSession()
                let htmlExams = try await parser.parseExams(startDate: startDate, endDate: endDate)
                let exams = convertHTMLExams(htmlExams)
                print("📝 Retrieved \(exams.count) exams via HTML parser")
                return exams
            } catch {
                print("❌ HTML exam parsing failed: \(error.localizedDescription)")
                lastError = error
            }
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
            // Build the correct full API URL with the working jsonrpc.do endpoint
            let fullApiUrl = WebUntisURLParser.buildJsonRpcApiUrl(server: serverURL, school: schoolName)
            capabilities.supportsJSONRPC = await jsonrpcClient.testConnection(server: fullApiUrl, schoolName: schoolName)
            if capabilities.supportsJSONRPC {
                // Test enhanced methods if JSONRPC works
                let supportedMethods = await jsonrpcClient.testBetterUntisSupport()
                capabilities.supportedJSONRPCMethods = supportedMethods.compactMap { $0.value ? $0.key : nil }
                print("📡 JSONRPC API support: \(capabilities.supportsJSONRPC) with \(capabilities.supportedJSONRPCMethods.count) enhanced methods")
            } else {
                print("📡 JSONRPC API not supported by this server - will use HTML fallback")
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
            _ = keychain.save(string: String(data: data, encoding: .utf8) ?? "", forKey: "capabilities_\(key)")
            print("💾 Saved server capabilities for \(key)")
        } catch {
            print("❌ Failed to save capabilities: \(error)")
        }
    }

    private func loadServerCapabilities(for key: String) {
        guard let jsonString = keychain.loadString(forKey: "capabilities_\(key)"),
              let data = jsonString.data(using: .utf8) else { return }

        do {
            serverCapabilities = try JSONDecoder().decode(ServerCapabilities.self, from: data)
            print("📂 Loaded cached server capabilities for \(key)")
        } catch {
            print("❌ Failed to load capabilities: \(error)")
        }
    }

    // MARK: - Utility Methods

    private func ensureHTMLSession(username: String? = nil, password: String? = nil) async throws -> WebUntisHTMLParser {
        let creds: (String, String)
        if let user = username, let pass = password {
            creds = (user, pass)
        } else if let stored = cachedCredentials {
            creds = stored
        } else {
            throw NSError(domain: "HybridService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing credentials for HTML fallback"])
        }

        guard !serverURL.isEmpty else {
            throw NSError(domain: "HybridService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server URL missing for HTML fallback"])
        }

        if htmlParser == nil {
            let encodedSchool = schoolName.replacingOccurrences(of: " ", with: "+")
            htmlParser = WebUntisHTMLParser(serverURL: serverURL, school: encodedSchool)
        }

        guard let parser = htmlParser else {
            throw NSError(domain: "HybridService", code: -1, userInfo: [NSLocalizedDescriptionKey: "HTML parser unavailable"])
        }

        if !parser.isAuthenticated {
            _ = try await parser.authenticate(username: creds.0, password: creds.1)
        }

        return parser
    }

    private func convertHTMLPeriods(_ periods: [HTMLParsedPeriod]) -> [Period] {
        return periods.compactMap { htmlPeriod in
            let identifier = Int64(abs(htmlPeriod.id.hashValue))
            let start = TimetableTransformer.combine(date: htmlPeriod.date, time: htmlPeriod.startTime)
            let end = TimetableTransformer.combine(date: htmlPeriod.date, time: htmlPeriod.endTime)

            let subjectName = htmlPeriod.subject ?? htmlPeriod.subjectCode ?? ""
            let teacherName = htmlPeriod.teacher ?? htmlPeriod.teacherCode ?? ""
            let roomName = htmlPeriod.room ?? htmlPeriod.roomCode ?? ""

            var elements = [PeriodElement]()
            if !teacherName.isEmpty {
                elements.append(PeriodElement(type: .teacher, id: identifier, name: teacherName, longName: teacherName, displayName: nil, alternateName: nil, backColor: nil, foreColor: nil, canViewTimetable: nil))
            }
            if !roomName.isEmpty {
                elements.append(PeriodElement(type: .room, id: identifier, name: roomName, longName: roomName, displayName: nil, alternateName: nil, backColor: nil, foreColor: nil, canViewTimetable: nil))
            }
            if !subjectName.isEmpty {
                elements.append(PeriodElement(type: .subject, id: identifier, name: subjectName, longName: subjectName, displayName: nil, alternateName: nil, backColor: nil, foreColor: nil, canViewTimetable: nil))
            }

            var periodStates: [PeriodState] = []
            switch htmlPeriod.status {
            case .cancelled: periodStates.append(.cancelled)
            case .exam: periodStates.append(.exam)
            case .substituted: periodStates.append(.teacherSubstitution)
            case .absent: periodStates.append(.irregular)
            default: break
            }

            let text = PeriodText(
                lesson: subjectName.isEmpty ? htmlPeriod.statusText : subjectName,
                substitution: htmlPeriod.substitutionInfo?.note,
                info: htmlPeriod.statusText
            )

            return Period(
                id: identifier,
                lessonId: identifier,
                startDateTime: start,
                endDateTime: end,
                foreColor: "#000000",
                backColor: "#FFFFFF",
                innerForeColor: "#000000",
                innerBackColor: "#FFFFFF",
                text: text,
                elements: elements,
                can: [],
                is: periodStates,
                homeWorks: nil,
                exam: nil,
                isOnlinePeriod: htmlPeriod.hasExam,
                messengerChannel: nil,
                onlinePeriodLink: nil,
                blockHash: nil
            )
        }
    }

    private func convertHTMLAbsences(_ absences: [HTMLParsedAbsence]) -> [StudentAbsence] {
        return absences.enumerated().map { index, absence in
            let start = TimetableTransformer.combine(date: absence.startDate, time: absence.startTime)
            let end = TimetableTransformer.combine(date: absence.endDate, time: absence.endTime)
            return StudentAbsence(
                id: index,
                studentId: 0,
                klasseId: nil,
                startDateTime: start,
                endDateTime: end,
                excused: absence.isExcused,
                absenceReason: absence.reason,
                excuse: nil,
                studentOfAge: nil,
                notification: nil,
                lastUpdate: absence.submittedAt
            )
        }
    }

    private func convertSaaAbsences(_ response: SaaDataResponse) -> [StudentAbsence] {
        return response.absences.compactMap { record in
            guard let student = record.student,
                  let start = parseSaaDate(record.duration.start),
                  let end = parseSaaDate(record.duration.end) else {
                return nil
            }

            let isExcused = record.excuseStatus?.type == .excused
            let reason = record.excuseText ?? record.text
            let studentOfAge = record.studentOfAge ?? student.studentOfAge

            return StudentAbsence(
                id: Int(record.id),
                studentId: Int(student.id),
                klasseId: nil,
                startDateTime: start,
                endDateTime: end,
                excused: isExcused,
                absenceReason: reason,
                excuse: nil,
                studentOfAge: studentOfAge,
                notification: nil,
                lastUpdate: nil
            )
        }
    }

    private func parseSaaDate(_ dateString: String) -> Date? {
        if let date = DateFormatter.untisDateTimeMinutes.date(from: dateString) {
            return date
        }
        if let date = DateFormatter.untisDateTime.date(from: dateString) {
            return date
        }
        if let date = DateFormatter.untisDate.date(from: dateString) {
            return date
        }
        return ISO8601DateFormatter().date(from: dateString)
    }

    private func convertHTMLHomework(_ items: [HTMLParsedHomework]) -> [HomeWork] {
        return items.enumerated().map { index, item in
            let attachments = item.attachments.map { attachment in
                HomeworkAttachment(
                    id: abs(attachment.id.hashValue) + index * 1000,
                    name: attachment.name,
                    url: attachment.url,
                    fileSize: attachment.fileSize,
                    mimeType: attachment.mimeType,
                    uploadDate: nil
                )
            }

            return HomeWork(
                id: index,
                lessonId: nil,
                subjectId: nil,
                teacherId: nil,
                startDate: item.assignedDate,
                endDate: item.dueDate,
                text: item.title,
                remark: item.description,
                completed: item.isCompleted,
                attachments: attachments,
                lastUpdate: item.completedDate
            )
        }
    }

    private func convertHTMLExams(_ exams: [HTMLParsedExam]) -> [EnhancedExam] {
        return exams.enumerated().map { index, exam in
            let generatedId = abs(exam.id.hashValue) + index * 100
            return EnhancedExam(
                id: generatedId,
                subjectId: 0,
                teacherId: nil,
                klasseId: nil,
                date: exam.date,
                startTime: exam.startTime,
                endTime: exam.endTime,
                examType: exam.examType,
                text: exam.description,
                remark: nil,
                lastUpdate: nil
            )
        }
    }

    /// Clear all authentication and reset state
    func logout() async {
        restClient.clearToken()
        try? await jsonrpcClient.logout()
        if let parser = htmlParser {
            try? await parser.logout()
        }
        htmlParser = nil
        cachedCredentials = nil
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

private enum TimetableTransformer {
    static func fromJSONRPC(timetableData: [String: Any]) -> [Period]? {
        guard let periodDicts = extractPeriodArray(from: timetableData), !periodDicts.isEmpty else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        var periods: [Period] = []
        for (index, entry) in periodDicts.enumerated() {
            if let period = buildPeriod(from: entry, index: index, formatter: dateFormatter) {
                periods.append(period)
            }
        }

        return periods
    }

    private static func extractPeriodArray(from data: [String: Any]) -> [[String: Any]]? {
        if let result = data["result"] as? [[String: Any]] {
            return result
        }

        if let resultDict = data["result"] as? [String: Any] {
            if let timetable = resultDict["timetable"] as? [[String: Any]] {
                return timetable
            }
            if let periods = resultDict["periods"] as? [[String: Any]] {
                return periods
            }
        }

        if let timetableObj = data["timetable"] as? [String: Any],
           let periods = timetableObj["periods"] as? [[String: Any]] {
            return periods
        }

        if let timetable = data["timetable"] as? [[String: Any]] {
            return timetable
        }

        if let periods = data["periods"] as? [[String: Any]] {
            return periods
        }

        if data.count == 1, let firstValue = data.values.first as? [[String: Any]] {
            return firstValue
        }

        return nil
    }

    private static func buildPeriod(from dict: [String: Any], index: Int, formatter: DateFormatter) -> Period? {
        let identifier = int64(from: dict["id"]) ?? Int64(index)
        let lessonId = int64(from: dict["lessonId"]) ?? identifier

        guard let baseDate = parseDate(dict["date"], formatter: formatter) else {
            return nil
        }

        let startDateTime = combine(date: baseDate, time: dict["startTime"])
        let endDateTime = combine(date: baseDate, time: dict["endTime"])

        let subjectName = firstName(in: dict["su"], defaultPrefix: "Subject")
        let teacherName = firstName(in: dict["te"], defaultPrefix: "Teacher")
        let className = firstName(in: dict["kl"], defaultPrefix: "Class")

        var elements: [PeriodElement] = []
        elements.append(contentsOf: makeElements(type: .teacher, from: dict["te"], defaultPrefix: "Teacher"))
        elements.append(contentsOf: makeElements(type: .room, from: dict["ro"], defaultPrefix: "Room"))
        elements.append(contentsOf: makeElements(type: .subject, from: dict["su"], defaultPrefix: "Subject"))
        elements.append(contentsOf: makeElements(type: .klasse, from: dict["kl"], defaultPrefix: "Class"))

        var states: [PeriodState] = []
        if let code = (dict["code"] as? String)?.lowercased() {
            switch code {
            case "cancelled": states.append(.cancelled)
            case "irregular": states.append(.irregular)
            case "exam": states.append(.exam)
            default: break
            }
        }

        if let flags = dict["statflags"] as? String, flags.lowercased().contains("absent") {
            states.append(.irregular)
        }

        let lessonText = subjectName ?? className ?? teacherName
        let infoText = dict["info"] as? String ?? dict["activityType"] as? String

        let periodText = PeriodText(
            lesson: lessonText,
            substitution: dict["substitutionText"] as? String,
            info: infoText
        )

        return Period(
            id: identifier,
            lessonId: lessonId,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            foreColor: dict["foreColor"] as? String ?? "#000000",
            backColor: dict["backColor"] as? String ?? "#FFFFFF",
            innerForeColor: dict["innerForeColor"] as? String ?? "#000000",
            innerBackColor: dict["innerBackColor"] as? String ?? "#FFFFFF",
            text: periodText,
            elements: elements,
            can: [],
            is: states,
            homeWorks: nil,
            exam: nil,
            isOnlinePeriod: dict["isOnlinePeriod"] as? Bool,
            messengerChannel: nil,
            onlinePeriodLink: dict["onlinePeriodLink"] as? String,
            blockHash: dict["blockHash"] as? Int
        )
    }

    private static func parseDate(_ value: Any?, formatter: DateFormatter) -> Date? {
        if let dateString = value as? String {
            if dateString.count == 8, let _ = Int(dateString) {
                return formatter.date(from: dateString)
            }
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
        }

        if let number = value as? Int {
            let padded = String(format: "%08d", number)
            return formatter.date(from: padded)
        }

        if let number = value as? Double {
            let intValue = Int(number)
            let padded = String(format: "%08d", intValue)
            return formatter.date(from: padded)
        }

        return nil
    }

    private static func makeElements(type: ElementType, from value: Any?, defaultPrefix: String) -> [PeriodElement] {
        guard let array = value as? [[String: Any]], !array.isEmpty else { return [] }
        return array.compactMap { entry in
            let id = int64(from: entry["id"]) ?? Int64(abs(UUID().uuidString.hashValue))
            let name = entry["name"] as? String ?? "\(defaultPrefix) \(id)"
            let longName = entry["longname"] as? String ?? name
            return PeriodElement(
                type: type,
                id: id,
                name: name,
                longName: longName,
                displayName: entry["displayname"] as? String,
                alternateName: entry["alternateName"] as? String,
                backColor: entry["backColor"] as? String,
                foreColor: entry["foreColor"] as? String,
                canViewTimetable: entry["canViewTimetable"] as? Bool
            )
        }
    }

    private static func firstName(in value: Any?, defaultPrefix: String) -> String? {
        guard let entry = (value as? [[String: Any]])?.first else { return nil }
        if let name = entry["name"] as? String, !name.isEmpty { return name }
        if let longName = entry["longname"] as? String, !longName.isEmpty { return longName }
        if let id = entry["id"] as? Int {
            return "\(defaultPrefix) \(id)"
        }
        return nil
    }

    static func combine(date: Date, time: Any?) -> Date {
        if let string = time as? String {
            return combine(date: date, time: string)
        }
        if let intValue = time as? Int {
            return combine(date: date, time: String(format: "%04d", intValue))
        }
        if let doubleValue = time as? Double {
            let intValue = Int(doubleValue)
            return combine(date: date, time: String(format: "%04d", intValue))
        }
        return date
    }

    static func combine(date: Date, time: String?) -> Date {
        guard let time, !time.isEmpty else { return date }
        let sanitized = time.replacingOccurrences(of: " ", with: "")
        let normalized: String
        if sanitized.contains(":") {
            normalized = sanitized.replacingOccurrences(of: ":", with: "")
        } else if sanitized.contains(".") {
            normalized = sanitized.replacingOccurrences(of: ".", with: "")
        } else {
            normalized = sanitized
        }

        guard normalized.count == 4, let value = Int(normalized) else { return date }
        let hour = value / 100
        let minute = value % 100
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    private static func int64(from value: Any?) -> Int64? {
        if let intValue = value as? Int {
            return Int64(intValue)
        }
        if let int64Value = value as? Int64 {
            return int64Value
        }
        if let stringValue = value as? String, let intValue = Int(stringValue) {
            return Int64(intValue)
        }
        return nil
    }
}
