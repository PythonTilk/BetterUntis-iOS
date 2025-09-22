import Foundation

/// Represents a timetable period with enhanced status information parsed from HTML
public struct HTMLParsedPeriod: Codable, Identifiable {
    public let id: String
    public let date: Date
    public let startTime: String
    public let endTime: String
    public let subject: String?
    public let subjectCode: String?
    public let teacher: String?
    public let teacherCode: String?
    public let room: String?
    public let roomCode: String?
    public let periodNumber: Int?
    public let status: HTMLPeriodStatus
    public let statusText: String?
    public let isAbsent: Bool
    public let isCancelled: Bool
    public let isSubstituted: Bool
    public let substitutionInfo: HTMLSubstitutionInfo?
    public let hasExam: Bool
    public let examInfo: String?

    public init(
        id: String,
        date: Date,
        startTime: String,
        endTime: String,
        subject: String? = nil,
        subjectCode: String? = nil,
        teacher: String? = nil,
        teacherCode: String? = nil,
        room: String? = nil,
        roomCode: String? = nil,
        periodNumber: Int? = nil,
        status: HTMLPeriodStatus = .normal,
        statusText: String? = nil,
        isAbsent: Bool = false,
        isCancelled: Bool = false,
        isSubstituted: Bool = false,
        substitutionInfo: HTMLSubstitutionInfo? = nil,
        hasExam: Bool = false,
        examInfo: String? = nil
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.subject = subject
        self.subjectCode = subjectCode
        self.teacher = teacher
        self.teacherCode = teacherCode
        self.room = room
        self.roomCode = roomCode
        self.periodNumber = periodNumber
        self.status = status
        self.statusText = statusText
        self.isAbsent = isAbsent
        self.isCancelled = isCancelled
        self.isSubstituted = isSubstituted
        self.substitutionInfo = substitutionInfo
        self.hasExam = hasExam
        self.examInfo = examInfo
    }
}

/// Status of a timetable period
public enum HTMLPeriodStatus: String, CaseIterable, Codable {
    case normal = "normal"
    case cancelled = "cancelled"
    case substituted = "substituted"
    case absent = "absent"
    case excused = "excused"
    case exam = "exam"
    case rescheduled = "rescheduled"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .cancelled:
            return "Cancelled"
        case .substituted:
            return "Substituted"
        case .absent:
            return "Absent"
        case .excused:
            return "Excused"
        case .exam:
            return "Exam"
        case .rescheduled:
            return "Rescheduled"
        case .unknown:
            return "Unknown"
        }
    }
}

/// Information about a substitution
public struct HTMLSubstitutionInfo: Codable {
    public let originalTeacher: String?
    public let substituteTeacher: String?
    public let originalRoom: String?
    public let substituteRoom: String?
    public let originalSubject: String?
    public let substituteSubject: String?
    public let reason: String?
    public let note: String?

    public init(
        originalTeacher: String? = nil,
        substituteTeacher: String? = nil,
        originalRoom: String? = nil,
        substituteRoom: String? = nil,
        originalSubject: String? = nil,
        substituteSubject: String? = nil,
        reason: String? = nil,
        note: String? = nil
    ) {
        self.originalTeacher = originalTeacher
        self.substituteTeacher = substituteTeacher
        self.originalRoom = originalRoom
        self.substituteRoom = substituteRoom
        self.originalSubject = originalSubject
        self.substituteSubject = substituteSubject
        self.reason = reason
        self.note = note
    }
}
