import Foundation

enum ElementType: Int, Codable, CaseIterable, Sendable {
    case klasse = 1
    case teacher = 2
    case subject = 3
    case room = 4
    case student = 5
}

enum PeriodRight: String, Codable, CaseIterable, Sendable {
    case delete = "DELETE"
    case edit = "EDIT"
    case createAbsence = "CREATE_ABSENCE"
    case editAbsence = "EDIT_ABSENCE"
    case deleteAbsence = "DELETE_ABSENCE"
    case canViewDetails = "CAN_VIEW_DETAILS"
}

enum PeriodState: String, Codable, CaseIterable, Sendable {
    case regular = "REGULAR"
    case cancelled = "CANCELLED"
    case irregular = "IRREGULAR"
    case exam = "EXAM"
    case roomSubstitution = "ROOMSUBSTITUTION"
    case teacherSubstitution = "TEACHERSUBSTITUTION"
    case subjectSubstitution = "SUBJECTSUBSTITUTION"
    case `break` = "BREAK"
}

enum ErrorCategory: String, Codable, Sendable {
    case authentication = "AUTHENTICATION"
    case authorization = "AUTHORIZATION"
    case badRequest = "BAD_REQUEST"
    case serverError = "SERVER_ERROR"
    case notFound = "NOT_FOUND"
}

enum DeviceOS: String, Codable, Sendable {
    case ios = "IOS"
    case android = "ANDROID"
}

enum CreateAbsenceStrategy: String, Codable, Sendable {
    case automatic = "AUTOMATIC"
    case manual = "MANUAL"
    case disabled = "DISABLED"
}

enum DefaultAbsenceEndTime: String, Codable, Sendable {
    case periodEnd = "PERIOD_END"
    case dayEnd = "DAY_END"
    case custom = "CUSTOM"
}