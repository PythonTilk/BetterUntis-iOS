import Foundation

struct UserData: Codable {
    let masterId: Int64
    let personType: ElementType
    let personId: Int64
    let displayName: String
    let schoolName: String
    let departmentId: Int64?
    let klasseId: Int64?
    let rights: [String]
}

struct UserDataResult: Codable {
    let masterData: MasterData
    let userData: UserData
    let settings: Settings?
}

struct Settings: Codable {
    let showAbsenceReason: Bool?
    let showAbsenceText: Bool?
    let defaultAbsenceEndTime: DefaultAbsenceEndTime?
    let defaultAbsenceReasonId: Int64?
    let createAbsenceStrategy: CreateAbsenceStrategy?
}

struct SchoolInfo: Codable {
    let schoolId: String?
    let loginName: String?
    let displayName: String?
    let serverUrl: String?
    let mobileServiceUrl: String?
    let useMobileServiceUrlAndroid: Bool?
    let address: String?
}

struct MasterData: Codable {
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
struct AbsenceReason: Codable, Identifiable {
    let id: Int64
    let name: String
    let longName: String
    let active: Bool
}

struct Department: Codable, Identifiable {
    let id: Int64
    let name: String
    let longName: String
}

struct Duty: Codable, Identifiable {
    let id: Int64
    let name: String
    let longName: String
}

struct EventReason: Codable, Identifiable {
    let id: Int64
    let name: String
    let longName: String
    let groupId: Int64?
}

struct EventReasonGroup: Codable, Identifiable {
    let id: Int64
    let name: String
}

struct ExcuseStatus: Codable, Identifiable {
    let id: Int64
    let name: String
    let longName: String
}

struct Holiday: Codable, Identifiable {
    let id: Int64
    let name: String
    let longName: String
    let startDate: Date
    let endDate: Date
}

struct Klasse: Codable, Identifiable {
    let id: Int64
    let name: String
    let longName: String
    let active: Bool
    let did: Int64?
}

struct Room: Codable, Identifiable {
    let id: Int64
    let name: String
    let longName: String
    let active: Bool
    let building: String?
}

struct Subject: Codable, Identifiable {
    let id: Int64
    let name: String
    let longName: String
    let active: Bool
    let backColor: String?
    let foreColor: String?
}

struct Teacher: Codable, Identifiable {
    let id: Int64
    let name: String
    let longName: String
    let active: Bool
    let title: String?
    let entryDate: Date?
    let exitDate: Date?
}

struct TeachingMethod: Codable, Identifiable {
    let id: Int64
    let name: String
    let longName: String
}

struct SchoolYear: Codable, Identifiable {
    let id: Int64
    let name: String
    let startDate: Date
    let endDate: Date
}

struct TimeGrid: Codable {
    let days: [Day]
}

struct Day: Codable {
    let day: Int
    let timeUnits: [TimeUnit]
}

struct TimeUnit: Codable {
    let name: String
    let startTime: String
    let endTime: String
}