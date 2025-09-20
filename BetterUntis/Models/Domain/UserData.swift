import Foundation

struct UserData: Codable, Sendable {
    let masterId: Int64
    let personType: ElementType
    let personId: Int64
    let displayName: String
    let schoolName: String
    let departmentId: Int64?
    let klasseId: Int64?
    let rights: [String]
}

struct UserDataResult: Codable, @unchecked Sendable {
    let masterData: MasterData
    let userData: UserData
    let settings: Settings?
}

struct Settings: Codable, Sendable {
    let showAbsenceReason: Bool?
    let showAbsenceText: Bool?
    let defaultAbsenceEndTime: DefaultAbsenceEndTime?
    let defaultAbsenceReasonId: Int64?
    let createAbsenceStrategy: CreateAbsenceStrategy?
}

struct SchoolInfo: Codable, Sendable {
    let schoolId: String?
    let loginName: String?
    let displayName: String?
    let serverUrl: String?
    let mobileServiceUrl: String?
    let useMobileServiceUrlAndroid: Bool?
    let address: String?
}

struct MasterData: Codable, Sendable {
    let timeStamp: Int64
    let absenceReasons: [AbsenceReason]?
    let departments: [Department]?
    let duties: [Duty]?
    let eventReasons: [EventReason]?
    let eventReasonGroups: [EventReasonGroup]?
    let excuseStatuses: [ExcuseStatus]?
    let holidays: [Holiday]?
    let klassen: [Klasse]
    let rooms: [Room]
    let subjects: [Subject]
    let teachers: [Teacher]
    let teachingMethods: [TeachingMethod]?
    let schoolyears: [SchoolYear]?
    let timeGrid: TimeGrid
}

// Master data entities
struct AbsenceReason: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
    let active: Bool
}

struct Department: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
}

struct Duty: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
}

struct EventReason: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
    let groupId: Int64?
}

struct EventReasonGroup: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
}

struct ExcuseStatus: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
}

struct Holiday: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
    let startDate: Date
    let endDate: Date
}

struct Klasse: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
    let active: Bool
    let did: Int64?
}

struct Room: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
    let active: Bool
    let building: String?
}

struct Subject: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
    let active: Bool
    let backColor: String?
    let foreColor: String?
}

struct Teacher: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
    let active: Bool
    let title: String?
    let entryDate: Date?
    let exitDate: Date?
}

struct TeachingMethod: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
}

struct SchoolYear: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let startDate: Date
    let endDate: Date
}

struct TimeGrid: Codable, Sendable {
    let days: [Day]
}

struct Day: Codable, Sendable {
    let day: Int
    let timeUnits: [TimeUnit]
}

struct TimeUnit: Codable, Sendable {
    let name: String
    let startTime: String
    let endTime: String
}