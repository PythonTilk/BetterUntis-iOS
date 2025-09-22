import Foundation

enum ElementType: String, Codable, CaseIterable {
    case klasse = "KLASSE"
    case teacher = "TEACHER"
    case subject = "SUBJECT"
    case room = "ROOM"
    case student = "STUDENT"
}

enum PeriodRight: String, Codable, CaseIterable {
    case delete = "DELETE"
    case edit = "EDIT"
    case createAbsence = "CREATE_ABSENCE"
    case editAbsence = "EDIT_ABSENCE"
    case deleteAbsence = "DELETE_ABSENCE"
    case canViewDetails = "CAN_VIEW_DETAILS"
}

enum PeriodState: String, Codable, CaseIterable {
    case regular = "REGULAR"
    case cancelled = "CANCELLED"
    case irregular = "IRREGULAR"
    case exam = "EXAM"
    case roomSubstitution = "ROOMSUBSTITUTION"
    case teacherSubstitution = "TEACHERSUBSTITUTION"
    case subjectSubstitution = "SUBJECTSUBSTITUTION"
    case break = "BREAK"
}

enum ErrorCategory: String, Codable {
    case authentication = "AUTHENTICATION"
    case authorization = "AUTHORIZATION"
    case badRequest = "BAD_REQUEST"
    case serverError = "SERVER_ERROR"
    case notFound = "NOT_FOUND"
}

enum DeviceOS: String, Codable {
    case ios = "IOS"
    case android = "ANDROID"
}

enum CreateAbsenceStrategy: String, Codable {
    case automatic = "AUTOMATIC"
    case manual = "MANUAL"
    case disabled = "DISABLED"
}

enum DefaultAbsenceEndTime: String, Codable {
    case periodEnd = "PERIOD_END"
    case dayEnd = "DAY_END"
    case custom = "CUSTOM"
}