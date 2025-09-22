import Foundation

// MARK: - API Parameter Models

struct TimetableParams: Codable {
    let id: Int64
    let type: String
    let startDate: String // ISO date string
    let endDate: String   // ISO date string
    let masterDataTimestamp: Int64
    let timetableTimestamp: Int64
    let timetableTimestamps: [Int64]
    let auth: Auth

    init(id: Int64, type: ElementType, startDate: Date, endDate: Date,
         masterDataTimestamp: Int64, timetableTimestamp: Int64 = 0,
         timetableTimestamps: [Int64] = [], auth: Auth) {
        self.id = id
        self.type = type.rawValue
        self.startDate = DateFormatter.iso8601Date.string(from: startDate)
        self.endDate = DateFormatter.iso8601Date.string(from: endDate)
        self.masterDataTimestamp = masterDataTimestamp
        self.timetableTimestamp = timetableTimestamp
        self.timetableTimestamps = timetableTimestamps
        self.auth = auth
    }
}

struct UserDataParams: Codable {
    let auth: Auth
}

struct AppSharedSecretParams: Codable {
    let user: String
    let password: String
    let token: String?

    init(user: String, password: String, token: String? = nil) {
        self.user = user
        self.password = password
        self.token = token
    }
}

struct AuthTokenParams: Codable {
    let auth: Auth
}

struct PeriodDataParams: Codable {
    let ttIds: Set<Int64>
    let auth: Auth

    init(periodIds: Set<Int64>, auth: Auth) {
        self.ttIds = periodIds
        self.auth = auth
    }
}

struct SchoolSearchParams: Codable {
    let search: String
}

struct MessagesOfDayParams: Codable {
    let date: String // ISO date string
    let auth: Auth

    init(date: Date, auth: Auth) {
        self.date = DateFormatter.iso8601Date.string(from: date)
        self.auth = auth
    }
}

struct StudentAbsencesParams: Codable {
    let startDate: String // ISO date string
    let endDate: String   // ISO date string
    let auth: Auth

    init(startDate: Date, endDate: Date, auth: Auth) {
        self.startDate = DateFormatter.iso8601Date.string(from: startDate)
        self.endDate = DateFormatter.iso8601Date.string(from: endDate)
        self.auth = auth
    }
}

struct ExamsParams: Codable {
    let startDate: String // ISO date string
    let endDate: String   // ISO date string
    let auth: Auth

    init(startDate: Date, endDate: Date, auth: Auth) {
        self.startDate = DateFormatter.iso8601Date.string(from: startDate)
        self.endDate = DateFormatter.iso8601Date.string(from: endDate)
        self.auth = auth
    }
}

struct HomeworkParams: Codable {
    let startDate: String // ISO date string
    let endDate: String   // ISO date string
    let auth: Auth

    init(startDate: Date, endDate: Date, auth: Auth) {
        self.startDate = DateFormatter.iso8601Date.string(from: startDate)
        self.endDate = DateFormatter.iso8601Date.string(from: endDate)
        self.auth = auth
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let iso8601Date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    static let iso8601DateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter
    }()
}