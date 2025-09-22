import Foundation

/// Represents homework parsed from WebUntis HTML
public struct HTMLParsedHomework: Codable, Identifiable {
    public let id: String
    public let subject: String
    public let subjectCode: String?
    public let teacher: String?
    public let teacherCode: String?
    public let assignedDate: Date
    public let dueDate: Date
    public let title: String
    public let description: String
    public let attachments: [HTMLParsedHomeworkAttachment]
    public let isCompleted: Bool
    public let completedDate: Date?
    public let priority: HTMLHomeworkPriority

    public init(
        id: String,
        subject: String,
        subjectCode: String? = nil,
        teacher: String? = nil,
        teacherCode: String? = nil,
        assignedDate: Date,
        dueDate: Date,
        title: String,
        description: String,
        attachments: [HTMLParsedHomeworkAttachment] = [],
        isCompleted: Bool = false,
        completedDate: Date? = nil,
        priority: HTMLHomeworkPriority = .normal
    ) {
        self.id = id
        self.subject = subject
        self.subjectCode = subjectCode
        self.teacher = teacher
        self.teacherCode = teacherCode
        self.assignedDate = assignedDate
        self.dueDate = dueDate
        self.title = title
        self.description = description
        self.attachments = attachments
        self.isCompleted = isCompleted
        self.completedDate = completedDate
        self.priority = priority
    }
}

/// Represents a homework attachment
public struct HTMLParsedHomeworkAttachment: Codable, Identifiable {
    public let id: String
    public let name: String
    public let url: String?
    public let fileSize: Int?
    public let mimeType: String?

    public init(
        id: String,
        name: String,
        url: String? = nil,
        fileSize: Int? = nil,
        mimeType: String? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.fileSize = fileSize
        self.mimeType = mimeType
    }
}

/// Priority levels for homework
public enum HTMLHomeworkPriority: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"

    public var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .normal:
            return "Normal"
        case .high:
            return "High"
        case .urgent:
            return "Urgent"
        }
    }
}
