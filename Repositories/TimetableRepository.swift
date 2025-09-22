import Foundation
import CoreData
import Combine

class TimetableRepository: ObservableObject {
    private let apiClient = UntisAPIClient()
    private let persistenceController = PersistenceController.shared
    private let keychainManager = KeychainManager.shared

    @Published var currentTimetable: Timetable?
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date?

    // MARK: - Timetable Loading

    func loadTimetable(
        for user: User,
        startDate: Date,
        endDate: Date,
        forceRefresh: Bool = false
    ) async throws {
        await MainActor.run {
            isLoading = true
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        // Try to load from cache first if not forcing refresh
        if !forceRefresh, let cachedTimetable = loadCachedTimetable(for: user, startDate: startDate, endDate: endDate) {
            await MainActor.run {
                self.currentTimetable = cachedTimetable
                self.lastUpdated = Date()
            }
            return
        }

        // Load from API
        guard let credentials = keychainManager.loadUserCredentials(userId: String(user.id)) else {
            throw TimetableError.missingCredentials
        }

        do {
            let jsonRpcApiUrl = buildJsonRpcApiUrl(apiUrl: user.apiHost, schoolName: user.schoolName)

            let timetableResult = try await apiClient.getTimetable(
                apiUrl: jsonRpcApiUrl,
                id: user.id,
                type: .student, // Default to student view, could be configurable
                startDate: startDate,
                endDate: endDate,
                masterDataTimestamp: user.masterDataTimestamp,
                user: credentials.user,
                key: credentials.key
            )

            // Cache the timetable
            try cacheTimetable(timetableResult.timetable, for: user)

            await MainActor.run {
                self.currentTimetable = timetableResult.timetable
                self.lastUpdated = Date()
            }

        } catch {
            throw error
        }
    }

    func getTimetableForWeek(
        user: User,
        weekStartDate: Date
    ) async throws -> Timetable {
        let calendar = Calendar.current
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate)!

        try await loadTimetable(for: user, startDate: weekStartDate, endDate: weekEndDate)

        return currentTimetable ?? Timetable(
            displayableStartDate: weekStartDate,
            displayableEndDate: weekEndDate,
            periods: []
        )
    }

    func getTimetableForDay(
        user: User,
        date: Date
    ) async throws -> [Period] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        try await loadTimetable(for: user, startDate: startOfDay, endDate: endOfDay)

        return currentTimetable?.periods.filter { period in
            calendar.isDate(period.startDateTime, inSameDayAs: date)
        } ?? []
    }

    // MARK: - Caching

    private func loadCachedTimetable(for user: User, startDate: Date, endDate: Date) -> Timetable? {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<PeriodEntity> = NSFetchRequest(entityName: "PeriodEntity")

        request.predicate = NSPredicate(
            format: "userId == %lld AND startDateTime >= %@ AND endDateTime <= %@",
            user.id, startDate as NSDate, endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PeriodEntity.startDateTime, ascending: true)]

        do {
            let periodEntities = try context.fetch(request)
            let periods = periodEntities.map { $0.toDomainModel() }

            if !periods.isEmpty {
                return Timetable(
                    displayableStartDate: startDate,
                    displayableEndDate: endDate,
                    periods: periods
                )
            }
        } catch {
            print("Failed to load cached timetable: \(error)")
        }

        return nil
    }

    private func cacheTimetable(_ timetable: Timetable, for user: User) throws {
        let context = persistenceController.container.viewContext

        // Clear existing cached periods for this time range
        let deleteRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "PeriodEntity")
        deleteRequest.predicate = NSPredicate(
            format: "userId == %lld AND startDateTime >= %@ AND endDateTime <= %@",
            user.id,
            timetable.displayableStartDate as NSDate,
            timetable.displayableEndDate as NSDate
        )

        let deleteRequestBatch = NSBatchDeleteRequest(fetchRequest: deleteRequest)
        try context.execute(deleteRequestBatch)

        // Save new periods
        for period in timetable.periods {
            let periodEntity = PeriodEntity(context: context)
            periodEntity.update(from: period, userId: user.id)
        }

        try context.save()
        persistenceController.save()
    }

    // MARK: - Helper Methods

    private func buildJsonRpcApiUrl(apiUrl: String, schoolName: String) -> String {
        var components = URLComponents(string: apiUrl)!
        if !components.path.contains("/WebUntis") {
            components.path += "/WebUntis"
        }
        components.path += "/jsonrpc_intern.do"
        components.queryItems = [URLQueryItem(name: "school", value: schoolName)]
        return components.url!.absoluteString
    }

    // MARK: - Period Details

    func getPeriodDetails(
        user: User,
        periodIds: Set<Int64>
    ) async throws -> [Period] {
        guard let credentials = keychainManager.loadUserCredentials(userId: String(user.id)) else {
            throw TimetableError.missingCredentials
        }

        let jsonRpcApiUrl = buildJsonRpcApiUrl(apiUrl: user.apiHost, schoolName: user.schoolName)

        let periodDataResult = try await apiClient.getPeriodData(
            apiUrl: jsonRpcApiUrl,
            periodIds: periodIds,
            user: credentials.user,
            key: credentials.key
        )

        return periodDataResult.periods
    }

    // MARK: - Utility Methods

    func getPeriodsForDateRange(_ startDate: Date, _ endDate: Date) -> [Period] {
        return currentTimetable?.periods.filter { period in
            period.startDateTime >= startDate && period.endDateTime <= endDate
        } ?? []
    }

    func getCurrentPeriod(at date: Date = Date()) -> Period? {
        return currentTimetable?.periods.first { period in
            date >= period.startDateTime && date <= period.endDateTime
        }
    }

    func getUpcomingPeriod(after date: Date = Date()) -> Period? {
        return currentTimetable?.periods
            .filter { $0.startDateTime > date }
            .min(by: { $0.startDateTime < $1.startDateTime })
    }
}

// MARK: - Supporting Types

enum TimetableError: Error, LocalizedError {
    case missingCredentials
    case invalidDateRange
    case noDataAvailable

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "User credentials not found"
        case .invalidDateRange:
            return "Invalid date range specified"
        case .noDataAvailable:
            return "No timetable data available"
        }
    }
}

// Core Data entity for Period
@objc(PeriodEntity)
public class PeriodEntity: NSManagedObject {
    @NSManaged public var id: Int64
    @NSManaged public var lessonId: Int64
    @NSManaged public var startDateTime: Date
    @NSManaged public var endDateTime: Date
    @NSManaged public var foreColor: String
    @NSManaged public var backColor: String
    @NSManaged public var userId: Int64

    func toDomainModel() -> Period {
        // This is a simplified conversion - in a real app you'd store more period data
        return Period(
            id: self.id,
            lessonId: self.lessonId,
            startDateTime: self.startDateTime,
            endDateTime: self.endDateTime,
            foreColor: self.foreColor,
            backColor: self.backColor,
            innerForeColor: self.foreColor,
            innerBackColor: self.backColor,
            text: PeriodText(lesson: "Cached Lesson", substitution: nil, info: nil),
            elements: [],
            can: [],
            is: [],
            homeWorks: nil,
            exam: nil,
            isOnlinePeriod: nil,
            messengerChannel: nil,
            onlinePeriodLink: nil,
            blockHash: nil
        )
    }

    func update(from period: Period, userId: Int64) {
        self.id = period.id
        self.lessonId = period.lessonId
        self.startDateTime = period.startDateTime
        self.endDateTime = period.endDateTime
        self.foreColor = period.foreColor
        self.backColor = period.backColor
        self.userId = userId
    }
}