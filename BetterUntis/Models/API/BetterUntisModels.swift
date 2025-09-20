import Foundation

// MARK: - Authentication Models

/// JWT Authentication response from BetterUntis mobile API
struct AuthResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let token_type: String
    let expires_in: Int?
    let scope: String?
    let flags: AuthFlags?
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
    let result: TimetableResult
    let resultSize: Int
    let totalResultSize: Int?
}

struct TimetableResult: Codable {
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

enum APIVersion: String {
    case v1 = "v1"
    case v2 = "v2"
    case v3 = "v3"
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

    static let untisTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}