import Foundation

/// Represents an exam parsed from WebUntis HTML
public struct HTMLParsedExam: Codable, Identifiable {
    public let id: String
    public let date: Date
    public let startTime: String
    public let endTime: String
    public let subject: String
    public let subjectCode: String?
    public let teacher: String?
    public let teacherCode: String?
    public let room: String?
    public let roomCode: String?
    public let examType: String
    public let description: String?
    public let duration: Int? // in minutes
    public let isWritten: Bool
    public let isOral: Bool

    public init(
        id: String,
        date: Date,
        startTime: String,
        endTime: String,
        subject: String,
        subjectCode: String? = nil,
        teacher: String? = nil,
        teacherCode: String? = nil,
        room: String? = nil,
        roomCode: String? = nil,
        examType: String = "exam",
        description: String? = nil,
        duration: Int? = nil,
        isWritten: Bool = true,
        isOral: Bool = false
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
        self.examType = examType
        self.description = description
        self.duration = duration
        self.isWritten = isWritten
        self.isOral = isOral
    }
}

/// Types of exams that can be parsed
public enum HTMLExamType: String, CaseIterable, Codable {
    case written = "written"
    case oral = "oral"
    case practical = "practical"
    case test = "test"
    case quiz = "quiz"
    case presentation = "presentation"
    case project = "project"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .written:
            return "Written Exam"
        case .oral:
            return "Oral Exam"
        case .practical:
            return "Practical Exam"
        case .test:
            return "Test"
        case .quiz:
            return "Quiz"
        case .presentation:
            return "Presentation"
        case .project:
            return "Project"
        case .unknown:
            return "Exam"
        }
    }
}
