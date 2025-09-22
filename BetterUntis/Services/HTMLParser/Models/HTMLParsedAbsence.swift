import Foundation

/// Represents a student absence parsed from WebUntis HTML
public struct HTMLParsedAbsence: Codable, Identifiable {
    public let id: String
    public let startDate: Date
    public let endDate: Date
    public let startTime: String?
    public let endTime: String?
    public let reason: String?
    public let reasonCode: String?
    public let isExcused: Bool
    public let isApproved: Bool
    public let comment: String?
    public let submittedBy: String?
    public let submittedAt: Date?

    public init(
        id: String,
        startDate: Date,
        endDate: Date,
        startTime: String? = nil,
        endTime: String? = nil,
        reason: String? = nil,
        reasonCode: String? = nil,
        isExcused: Bool = false,
        isApproved: Bool = false,
        comment: String? = nil,
        submittedBy: String? = nil,
        submittedAt: Date? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.startTime = startTime
        self.endTime = endTime
        self.reason = reason
        self.reasonCode = reasonCode
        self.isExcused = isExcused
        self.isApproved = isApproved
        self.comment = comment
        self.submittedBy = submittedBy
        self.submittedAt = submittedAt
    }
}

/// Represents the status of an absence
public enum HTMLAbsenceStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case excused = "excused"
    case unexcused = "unexcused"

    public var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .approved:
            return "Approved"
        case .rejected:
            return "Rejected"
        case .excused:
            return "Excused"
        case .unexcused:
            return "Unexcused"
        }
    }
}

/// Represents different types of absences
public enum HTMLAbsenceType: String, CaseIterable, Codable {
    case illness = "illness"
    case medical = "medical"
    case family = "family"
    case vacation = "vacation"
    case other = "other"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .illness:
            return "Illness"
        case .medical:
            return "Medical Appointment"
        case .family:
            return "Family Matter"
        case .vacation:
            return "Vacation"
        case .other:
            return "Other"
        case .unknown:
            return "Unknown"
        }
    }
}
