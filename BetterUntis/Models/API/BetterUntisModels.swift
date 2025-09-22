import Foundation

// MARK: - Authentication Models

/// JWT Authentication response from BetterUntis mobile API
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: Int?
    let scope: String?
    let flags: AuthFlags?

    private enum CodingKeys: String, CodingKey {
        case access_token
        case refresh_token
        case token_type
        case expires_in
        case scope
        case flags
        case jwt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let explicitToken = try container.decodeIfPresent(String.self, forKey: .access_token) {
            accessToken = explicitToken
        } else if let jwtToken = try container.decodeIfPresent(String.self, forKey: .jwt) {
            accessToken = jwtToken
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.access_token,
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Authentication response did not contain access token")
            )
        }

        refreshToken = try container.decodeIfPresent(String.self, forKey: .refresh_token)
        tokenType = try container.decodeIfPresent(String.self, forKey: .token_type) ?? "Bearer"
        expiresIn = try container.decodeIfPresent(Int.self, forKey: .expires_in)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        flags = try container.decodeIfPresent(AuthFlags.self, forKey: .flags)
    }

    init(
        accessToken: String,
        refreshToken: String?,
        tokenType: String,
        expiresIn: Int?,
        scope: String?,
        flags: AuthFlags?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.scope = scope
        self.flags = flags
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .access_token)
        try container.encodeIfPresent(refreshToken, forKey: .refresh_token)
        try container.encode(tokenType, forKey: .token_type)
        try container.encodeIfPresent(expiresIn, forKey: .expires_in)
        try container.encodeIfPresent(scope, forKey: .scope)
        try container.encodeIfPresent(flags, forKey: .flags)
    }
}

struct AuthFlags: Codable {
    let mustChangeEmail: Bool?
    let mustChangePassword: Bool?
    let forcePasswordChange: Bool?
}

struct AuthRequest: Codable {
    let username: String
    let password: String
    let client_id: String?
    let grant_type: String = "password"
}

// MARK: - Enhanced Absence Models

/// Enhanced student absence model matching BetterUntis structure
struct StudentAbsence: Codable, Identifiable {
    let id: Int
    let studentId: Int
    let klasseId: Int?
    let startDateTime: Date
    let endDateTime: Date
    let excused: Bool
    let absenceReason: String?
    let excuse: Excuse?
    let studentOfAge: Bool?
    let notification: AbsenceNotification?
    let lastUpdate: Date?

    // Computed properties for compatibility
    var isExcused: Bool { excused }
    var reason: String? { absenceReason }
}

struct Excuse: Codable {
    let id: Int
    let text: String?
    let isValid: Bool
    let userId: Int?
    let date: Date?
}

struct AbsenceNotification: Codable {
    let sent: Bool
    let sentDate: Date?
    let method: String?
}

// MARK: - Enhanced Homework Models

/// Enhanced homework model with attachments and completion tracking
struct HomeWork: Codable, Identifiable {
    let id: Int
    let lessonId: Int?
    let subjectId: Int?
    let teacherId: Int?
    let startDate: Date
    let endDate: Date
    let text: String
    let remark: String?
    let completed: Bool
    let attachments: [HomeworkAttachment]
    let lastUpdate: Date?

    // Computed properties for compatibility
    var subject: String? { nil } // Will be resolved via subjectId
    var teacher: String? { nil } // Will be resolved via teacherId
    var assignedDate: Date { startDate }
    var dueDate: Date { endDate }
    var title: String { text }
    var description: String { remark ?? text }
}

struct HomeworkAttachment: Codable, Identifiable {
    let id: Int
    let name: String
    let url: String?
    let fileSize: Int?
    let mimeType: String?
    let uploadDate: Date?
}

// MARK: - Enhanced Exam Models

/// Enhanced exam model with detailed scheduling information
struct EnhancedExam: Codable, Identifiable {
    let id: Int
    let subjectId: Int
    let teacherId: Int?
    let klasseId: Int?
    let date: Date
    let startTime: String
    let endTime: String
    let examType: String
    let text: String?
    let remark: String?
    let lastUpdate: Date?

    // Computed properties for compatibility
    var subject: String? { nil } // Will be resolved via subjectId
    var teacher: String? { nil } // Will be resolved via teacherId
}

// MARK: - Enhanced Timetable Models

/// Enhanced period data with status information
struct PeriodData: Codable {
    let id: Int
    let date: Date
    let startTime: String
    let endTime: String
    let subjectId: Int?
    let teacherId: Int?
    let roomId: Int?
    let klasseId: Int?
    let lessonCode: String?
    let activityType: String?
    let info: String?
    let substitution: SubstitutionInfo?
    let status: PeriodStatus
    let lastUpdate: Date?
}

struct SubstitutionInfo: Codable {
    let type: String
    let originalTeacherId: Int?
    let substituteTeacherId: Int?
    let originalRoomId: Int?
    let substituteRoomId: Int?
    let originalSubjectId: Int?
    let substituteSubjectId: Int?
    let reason: String?
    let text: String?
}

enum PeriodStatus: String, Codable, CaseIterable {
    case normal = "REGULAR"
    case cancelled = "CANCELLED"
    case substituted = "SUBSTITUTION"
    case absent = "ABSENT"
    case excused = "EXCUSED"
    case exam = "EXAM"
    case rescheduled = "IRREGULAR"
    case unknown = "UNKNOWN"
}

// MARK: - REST API Response Models

/// Timetable API v3 response structure
struct TimetableResponse: Codable {
    let data: TimetableData
    let meta: ResponseMeta?
}

struct TimetableData: Codable {
    let result: RESTTimetableResult
    let resultSize: Int
    let totalResultSize: Int?
}

struct RESTTimetableResult: Codable {
    let elements: [TimetableElement]
}

struct TimetableElement: Codable {
    let id: Int
    let date: String // ISO date format
    let startTime: String
    let endTime: String
    let kl: [TimetableElementRef]? // Classes
    let te: [TimetableElementRef]? // Teachers
    let su: [TimetableElementRef]? // Subjects
    let ro: [TimetableElementRef]? // Rooms
    let info: String?
    let code: String?
    let cellState: String?
    let activityType: String?
    let statflags: String?
    let sg: String?
    let bkRemark: String?
    let bkText: String?
}

struct TimetableElementRef: Codable {
    let id: Int
    let name: String?
    let longname: String?
    let orgname: String?
    let orgform: String?
}

struct ResponseMeta: Codable {
    let requestId: String?
    let timestamp: Date?
    let version: String?
}

// MARK: - Error Models

/// Enhanced error handling for BetterUntis APIs
struct UntisAPIError: Codable, Error {
    let code: Int
    let message: String
    let details: String?
    let timestamp: Date?

    var localizedDescription: String {
        return message
    }
}

// MARK: - Common Enums

enum RESTElementType: String, CaseIterable, Codable {
    case klasse = "CLASS"
    case teacher = "TEACHER"
    case subject = "SUBJECT"
    case room = "ROOM"
    case student = "STUDENT"
}

enum RESTCacheMode: String, Codable {
    case noCache = "NO_CACHE"
    case offlineOnly = "OFFLINE_ONLY"
    case onlineOnly = "ONLINE_ONLY"
    case fullCache = "FULL_CACHE"

    var cacheControlValue: String {
        switch self {
        case .noCache:
            return "no-store"
        case .offlineOnly:
            return "only-if-cached"
        case .onlineOnly:
            return "no-cache"
        case .fullCache:
            return "public, max-age=60"
        }
    }
}

enum RESTTimetableLayout: String, Codable {
    case startTime = "START_TIME"
    case priority = "PRIORITY"
}

enum RESTTimetableType: String, Codable {
    case myTimetable = "MY_TIMETABLE"
    case standard = "STANDARD"
    case overviewDay = "OVERVIEW_DAY"
    case overviewWeek = "OVERVIEW_WEEK"
    case officeHours = "OFFICE_HOURS"
}

enum APIVersion: String {
    case v1 = "v1"
    case v2 = "v2"
    case v3 = "v3"
}

// MARK: - REST Timetable Entries (view/v1)

struct TimetableEntriesResponse: Codable {
    let format: Int?
    let days: [TimetableEntriesDay]
}

struct TimetableEntriesDay: Codable {
    let date: String
    let resourceType: String
    let resource: TimetableResourceSummary?
    let status: String?
    let dayEntries: [TimetableDayEntry]
    let gridEntries: [TimetableGridEntry]
}

struct TimetableResourceSummary: Codable {
    let id: Int?
    let shortName: String?
    let longName: String?
    let displayName: String?
}

struct TimetableDayEntry: Codable {
    let ids: [Int]?
    let duration: TimetableDuration?
    let type: String?
    let status: String?
    let statusDetail: String?
    let name: String?
    let notesAll: String?
    let information: TimetableEntryInformation?
}

struct TimetableEntryInformation: Codable {
    let title: String?
    let text: String?
}

struct TimetableGridEntry: Codable {
    let ids: [Int]?
    let duration: TimetableDuration?
    let type: String?
    let status: String?
    let statusDetail: String?
    let name: String?
    let layoutStartPosition: Int?
    let layoutWidth: Int?
    let layoutGroup: Int?
    let color: String?
    let notesAll: String?
    let icons: [String]?
    let position1: [TimetablePositionItem]?
    let position2: [TimetablePositionItem]?
    let position3: [TimetablePositionItem]?
    let position4: [TimetablePositionItem]?
    let position5: [TimetablePositionItem]?
}

struct TimetableDuration: Codable {
    let start: String?
    let end: String?
}

struct TimetablePositionItem: Codable {
    let current: TimetablePositionContent?
    let original: TimetablePositionContent?
}

struct TimetablePositionContent: Codable {
    let text: String?
    let shortText: String?
    let id: Int?
    let type: String?
    let color: String?
    let foreColor: String?
    let backColor: String?
}

// MARK: - REST Room Finder

struct CalendarPeriodRoomResponse: Codable {
    let buildings: [CalendarPeriodRoomBuilding]
    let departments: [CalendarPeriodRoomDepartment]
    let roomTypes: [CalendarPeriodRoomType]
    let rooms: [CalendarPeriodRoomDetail]
}

struct CalendarPeriodRoomBuilding: Codable {
    let id: Int64
    let displayName: String
    let longName: String
    let shortName: String
}

struct CalendarPeriodRoomDepartment: Codable {
    let id: Int64
    let displayName: String
    let longName: String
    let shortName: String
}

struct CalendarPeriodRoomType: Codable {
    let id: Int64
    let displayName: String?
    let longName: String?
    let shortName: String?
}

struct CalendarPeriodRoomDetail: Codable {
    let id: Int64
    let displayName: String
    let longName: String
    let shortName: String
    let availability: CalendarPeriodRoomAvailability
    let status: CalendarPeriodRoomStatus
    let department: CalendarPeriodRoomDepartment?
    let building: CalendarPeriodRoomBuilding?
    let roomType: CalendarPeriodRoomType?
    let capacity: Int?
    let hasTimetable: Bool?
}

enum CalendarPeriodRoomAvailability: String, Codable {
    case none = "NONE"
    case bookable = "BOOKABLE"
    case reservable = "RESERVABLE"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? ""
        self = CalendarPeriodRoomAvailability(rawValue: rawValue) ?? .unknown
    }
}

enum CalendarPeriodRoomStatus: String, Codable {
    case regular = "REGULAR"
    case substitution = "SUBSTITUTION"
    case removed = "REMOVED"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? ""
        self = CalendarPeriodRoomStatus(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - REST Student Absence Administration

struct SaaDataRequest: Codable {
    let classId: Int64?
    let dateRange: SaaDateRange
    let dateRangeType: SaaDateRangeType?
    let studentId: Int64?
    let studentGroupId: Int64?
    let excuseStatusType: ExcuseStatusType?
    let filterForMissingLGNotifications: Bool?
}

struct SaaDataResponse: Codable {
    let absences: [SaaAbsence]
    let dateRange: SaaDateRange?
    let dateRangeType: SaaDateRangeType?
    let containsMissingLGNotifications: Bool?
}

struct SaaDateRange: Codable {
    let start: String
    let end: String
}

enum SaaDateRangeType: String, Codable {
    case day = "DAY"
    case week = "WEEK"
    case month = "MONTH"
    case schoolYear = "SCHOOL_YEAR"
    case lastWeek = "LAST_WEEK"
    case last14Days = "LAST_14_DAYS"
    case last30Days = "LAST_30_DAYS"
}

struct SaaAbsence: Codable {
    let id: Int64
    let deletable: Bool?
    let duration: SaaDateRange
    let editable: Bool?
    let excuseStatus: SaaExcuseStatus?
    let excuseStatusEditable: Bool?
    let excuseText: String?
    let student: SaaStudent?
    let text: String?
    let studentOfAge: Bool?
}

struct SaaExcuseStatus: Codable {
    let id: Int64
    let name: String
    let type: ExcuseStatusType
}

enum ExcuseStatusType: String, Codable {
    case open = "OPEN"
    case notExcused = "NOT_EXCUSED"
    case excused = "EXCUSED"
}

struct SaaStudent: Codable {
    let id: Int64
    let name: String?
    let studentOfAge: Bool?
}

// MARK: - Date/Time Extensions

extension DateFormatter {
    static let untisDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static let untisDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static let untisDateTimeMinutes: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static let untisTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
