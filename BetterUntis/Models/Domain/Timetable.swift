import Foundation

struct Timetable: Codable, Sendable {
    let displayableStartDate: Date
    let displayableEndDate: Date
    let periods: [Period]

    init(displayableStartDate: Date, displayableEndDate: Date, periods: [Period] = []) {
        self.displayableStartDate = displayableStartDate
        self.displayableEndDate = displayableEndDate
        self.periods = periods
    }
}

struct TimetableResult: Codable, @unchecked Sendable {
    let timetable: Timetable
    let masterData: MasterData?
}