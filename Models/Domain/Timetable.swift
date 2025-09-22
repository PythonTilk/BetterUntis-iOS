import Foundation

struct Timetable: Codable {
    let displayableStartDate: Date
    let displayableEndDate: Date
    let periods: [Period]

    init(displayableStartDate: Date, displayableEndDate: Date, periods: [Period] = []) {
        self.displayableStartDate = displayableStartDate
        self.displayableEndDate = displayableEndDate
        self.periods = periods
    }
}

struct TimetableResult: Codable {
    let timetable: Timetable
    let masterData: MasterData?
}