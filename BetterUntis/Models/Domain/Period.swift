import Foundation

struct Period: Codable, Identifiable, Sendable {
    let id: Int64
    let lessonId: Int64
    var startDateTime: Date
    var endDateTime: Date
    let foreColor: String
    let backColor: String
    let innerForeColor: String
    let innerBackColor: String
    let text: PeriodText
    let elements: [PeriodElement]
    let can: [PeriodRight]
    let `is`: [PeriodState]
    let homeWorks: [HomeWork]?
    let exam: PeriodExam?
    let isOnlinePeriod: Bool?
    let messengerChannel: MessengerChannel?
    let onlinePeriodLink: String?
    let blockHash: Int?

    // Helper methods matching the Android version
    func can(_ right: PeriodRight) -> Bool {
        return can.contains(right)
    }

    func `is`(_ state: PeriodState) -> Bool {
        return `is`.contains(state)
    }

    func equalsIgnoreTime(_ other: Period) -> Bool {
        return `is` == other.`is` &&
               can == other.can &&
               elements == other.elements &&
               text == other.text &&
               foreColor == other.foreColor &&
               backColor == other.backColor &&
               innerForeColor == other.innerForeColor &&
               innerBackColor == other.innerBackColor &&
               lessonId == other.lessonId
    }

    // Static constants
    static let codeRegular = "REGULAR"
    static let codeCancelled = "CANCELLED"
    static let codeIrregular = "IRREGULAR"
    static let codeExam = "EXAM"
}

struct PeriodText: Codable, Equatable, Sendable {
    let lesson: String?
    let substitution: String?
    let info: String?
}

struct PeriodElement: Codable, Equatable, Sendable {
    let type: ElementType
    let id: Int64
    let name: String
    let longName: String
    let displayName: String?
    let alternateName: String?
    let backColor: String?
    let foreColor: String?
    let canViewTimetable: Bool?
}

struct PeriodExam: Codable, Equatable, Sendable {
    let id: Int64?
    let examType: String?
    let name: String?
    let text: String?
}

struct HomeWork: Codable, Equatable, @unchecked Sendable {
    let id: Int64
    let lessonId: Int64
    let date: Date
    let dueDate: Date
    let text: String
    let remark: String?
    let completed: Bool
}

struct MessengerChannel: Codable, Equatable, Sendable {
    let id: String
    let name: String
}