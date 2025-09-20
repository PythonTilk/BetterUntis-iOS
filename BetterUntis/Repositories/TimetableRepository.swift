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
        // TEMPORARILY DISABLED FOR DEBUGGING - always force refresh to see live data
        /*
        if !forceRefresh, let cachedTimetable = loadCachedTimetable(for: user, startDate: startDate, endDate: endDate) {
            await MainActor.run {
                self.currentTimetable = cachedTimetable
                self.lastUpdated = Date()
            }
            return
        }
        */
        print("📊 Forcing live data refresh for debugging")

        // Load from API
        guard let credentials = keychainManager.loadUserCredentials(userId: String(user.id)) else {
            throw TimetableError.missingCredentials
        }

        do {
            // Use URLBuilder for robust URL construction with fallback support
            let apiUrls = try URLBuilder.buildApiUrlsWithFallback(
                apiHost: user.apiHost,
                schoolName: user.schoolName
            )

            var lastError: Error?
            var timetableResult: [String: Any]?

            // Try each URL until one works
            for apiUrl in apiUrls {
                do {
                    print("🔄 Trying timetable API URL: \(apiUrl)")
                    timetableResult = try await apiClient.getTimetable(
                        apiUrl: apiUrl,
                        id: user.id,
                        type: .student, // Default to student view, could be configurable
                        startDate: startDate,
                        endDate: endDate,
                        masterDataTimestamp: user.masterDataTimestamp,
                        user: credentials.user,
                        key: credentials.key
                    )
                    print("✅ Timetable loaded successfully with URL: \(apiUrl)")
                    break
                } catch {
                    print("❌ Timetable failed with URL \(apiUrl): \(error.localizedDescription)")
                    lastError = error
                    continue
                }
            }

            guard let result = timetableResult else {
                throw lastError ?? TimetableError.noDataAvailable
            }

            // Extract and store master data (including rooms) if present
            if let masterData = result["masterData"] as? [String: Any] {
                print("📊 Master data found but Core Data model needs RoomEntity - skipping storage for now")
                // TODO: Add RoomEntity to Core Data model, then re-enable this:
                // try storeMasterData(masterData, for: user)
            }

            // Parse timetable from dictionary
            let timetable = try parseTimetableFromDict(result, startDate: startDate, endDate: endDate)

            // Cache the timetable
            try cacheTimetable(timetable, for: user)

            await MainActor.run {
                self.currentTimetable = timetable
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

    private func parseTimetableFromDict(_ dict: [String: Any], startDate: Date, endDate: Date) throws -> Timetable {
        print("📊 Parsing timetable dictionary with keys: \(Array(dict.keys))")

        // Check for server compatibility message
        if let serverMessage = dict["serverMessage"] as? String {
            print("📋 Server message: \(serverMessage)")
        }

        // Try different possible data structures
        var periodsArray: [[String: Any]]?

        // Android BetterUntis format: { "timetable": { "periods": [...] } }
        if let timetableObj = dict["timetable"] as? [String: Any],
           let periods = timetableObj["periods"] as? [[String: Any]] {
            print("📊 Found Android format 'timetable.periods' array with \(periods.count) periods")
            periodsArray = periods
        }
        // Standard format: { "timetable": [...] }
        else if let timetable = dict["timetable"] as? [[String: Any]] {
            print("📊 Found standard 'timetable' array with \(timetable.count) periods")
            periodsArray = timetable
        }
        // Alternative format: { "periods": [...] }
        else if let periods = dict["periods"] as? [[String: Any]] {
            print("📊 Found 'periods' array with \(periods.count) periods")
            periodsArray = periods
        }
        // Another alternative: { "lessons": [...] }
        else if let lessons = dict["lessons"] as? [[String: Any]] {
            print("📊 Found 'lessons' array with \(lessons.count) lessons")
            periodsArray = lessons
        }
        // Direct array format (already wrapped by API client)
        else if dict["timetable"] == nil && dict.count == 1,
                let firstValue = dict.values.first as? [[String: Any]] {
            print("📊 Found direct array format with \(firstValue.count) items")
            periodsArray = firstValue
        }
        // Sometimes the result IS the array (this case is rare and likely won't match)
        else {
            print("⚠️ No recognizable period data structure found")
            print("📊 Available keys: \(Array(dict.keys))")
            if let timetableObj = dict["timetable"] as? [String: Any] {
                print("📊 Timetable object keys: \(Array(timetableObj.keys))")
            }
        }

        guard let periodsData = periodsArray else {
            print("⚠️ No recognizable timetable data found in response")
            return Timetable(displayableStartDate: startDate, displayableEndDate: endDate, periods: [])
        }

        if periodsData.isEmpty {
            print("⚠️ Timetable array is empty")
            return Timetable(displayableStartDate: startDate, displayableEndDate: endDate, periods: [])
        }

        print("📊 Processing \(periodsData.count) period entries")
        var periods: [Period] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        for (index, periodDict) in periodsData.enumerated() {
            print("📊 Processing period \(index + 1): keys = \(Array(periodDict.keys))")
            if let period = try? parsePeriodFromDict(periodDict, dateFormatter: dateFormatter) {
                periods.append(period)
                print("📊 Successfully parsed period \(index + 1)")
            } else {
                print("⚠️ Failed to parse period \(index + 1)")
                // Try to create a basic period with available data
                if let basicPeriod = createBasicPeriodFromDict(periodDict, index: Int64(index)) {
                    periods.append(basicPeriod)
                    print("📊 Created basic period \(index + 1)")
                }
            }
        }

        return Timetable(displayableStartDate: startDate, displayableEndDate: endDate, periods: periods)
    }

    private func parsePeriodFromDict(_ dict: [String: Any], dateFormatter: DateFormatter) throws -> Period {
        guard let id = dict["id"] as? Int64,
              let lessonId = dict["lessonId"] as? Int64,
              let date = dict["date"] as? String,
              let startTime = dict["startTime"] as? String,
              let endTime = dict["endTime"] as? String else {
            throw TimetableError.noDataAvailable
        }

        // Parse date and times
        guard let baseDate = dateFormatter.date(from: date) else {
            throw TimetableError.noDataAvailable
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"

        let calendar = Calendar.current

        var startDateTime = baseDate
        if let startTimeDate = timeFormatter.date(from: startTime) {
            let startComponents = calendar.dateComponents([.hour, .minute], from: startTimeDate)
            startDateTime = calendar.date(bySettingHour: startComponents.hour ?? 0,
                                        minute: startComponents.minute ?? 0,
                                        second: 0,
                                        of: baseDate) ?? baseDate
        }

        var endDateTime = baseDate
        if let endTimeDate = timeFormatter.date(from: endTime) {
            let endComponents = calendar.dateComponents([.hour, .minute], from: endTimeDate)
            endDateTime = calendar.date(bySettingHour: endComponents.hour ?? 0,
                                      minute: endComponents.minute ?? 0,
                                      second: 0,
                                      of: baseDate) ?? baseDate
        }

        return Period(
            id: id,
            lessonId: lessonId,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            foreColor: dict["foreColor"] as? String ?? "#000000",
            backColor: dict["backColor"] as? String ?? "#FFFFFF",
            innerForeColor: dict["innerForeColor"] as? String ?? "#000000",
            innerBackColor: dict["innerBackColor"] as? String ?? "#FFFFFF",
            text: PeriodText(
                lesson: (dict["su"] as? [String])?.joined(separator: ", "),
                substitution: nil,
                info: dict["info"] as? String
            ),
            elements: [],
            can: [],
            is: [],
            homeWorks: nil,
            exam: nil,
            isOnlinePeriod: dict["isOnlinePeriod"] as? Bool,
            messengerChannel: nil,
            onlinePeriodLink: dict["onlinePeriodLink"] as? String,
            blockHash: dict["blockHash"] as? Int
        )
    }

    private func createBasicPeriodFromDict(_ dict: [String: Any], index: Int64) -> Period? {
        print("📊 Attempting to create basic period from dict: \(dict)")

        // Try to extract basic information with flexible field names
        let id = (dict["id"] as? Int64)
               ?? (dict["periodId"] as? Int64)
               ?? (dict["lessonId"] as? Int64)
               ?? index

        let lessonId = (dict["lessonId"] as? Int64)
                    ?? (dict["id"] as? Int64)
                    ?? index

        // Try different date/time field combinations
        var startDateTime = Date()
        var endDateTime = Date()

        // Look for various date/time formats
        if let dateStr = dict["date"] as? String,
           let startTimeStr = dict["startTime"] as? String,
           let endTimeStr = dict["endTime"] as? String {

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"

            if let baseDate = dateFormatter.date(from: dateStr) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HHmm"

                let calendar = Calendar.current

                if let startTime = timeFormatter.date(from: startTimeStr) {
                    let components = calendar.dateComponents([.hour, .minute], from: startTime)
                    startDateTime = calendar.date(bySettingHour: components.hour ?? 8,
                                                minute: components.minute ?? 0,
                                                second: 0,
                                                of: baseDate) ?? baseDate
                }

                if let endTime = timeFormatter.date(from: endTimeStr) {
                    let components = calendar.dateComponents([.hour, .minute], from: endTime)
                    endDateTime = calendar.date(bySettingHour: components.hour ?? 9,
                                              minute: components.minute ?? 0,
                                              second: 0,
                                              of: baseDate) ?? baseDate.addingTimeInterval(3600)
                }
            }
        } else {
            // Fallback to current time if no date info
            startDateTime = Date()
            endDateTime = startDateTime.addingTimeInterval(3600) // 1 hour later
        }

        // Extract text/subject information - handle getLessons format
        var lessonText = ""

        // Try studentgroup field (common in getLessons response)
        if let studentGroup = dict["studentgroup"] as? String {
            lessonText = studentGroup
        }
        // Try activity type
        else if let activityType = dict["activityType"] as? String {
            lessonText = activityType
        }
        // Try subjects array with name resolution
        else if let subjects = dict["subjects"] as? [[String: Any]], !subjects.isEmpty {
            let subjectNames = subjects.compactMap { $0["name"] as? String }
            if !subjectNames.isEmpty {
                lessonText = subjectNames.joined(separator: ", ")
            } else {
                // Fallback to subject IDs
                let subjectIds = subjects.compactMap { $0["id"] as? Int }
                lessonText = "Subject \(subjectIds.map(String.init).joined(separator: ", "))"
            }
        }
        // Try legacy su field
        else if let subjects = (dict["su"] as? [String]) ?? (dict["subjects"] as? [String]), !subjects.isEmpty {
            lessonText = subjects.joined(separator: ", ")
        }
        // Ultimate fallback
        else {
            lessonText = "Course \(index + 1)"
        }

        // Add hours per week info if available
        if let hpw = dict["hpw"] as? Int, hpw > 0 {
            lessonText += " (\(hpw)h/week)"
        }

        let info = dict["info"] as? String

        print("📊 Creating basic period: id=\(id), lesson=\(lessonText), start=\(startDateTime), end=\(endDateTime)")

        return Period(
            id: id,
            lessonId: lessonId,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            foreColor: dict["foreColor"] as? String ?? "#000000",
            backColor: dict["backColor"] as? String ?? "#FFFFFF",
            innerForeColor: dict["innerForeColor"] as? String ?? "#000000",
            innerBackColor: dict["innerBackColor"] as? String ?? "#FFFFFF",
            text: PeriodText(
                lesson: lessonText,
                substitution: nil,
                info: info
            ),
            elements: [],
            can: [],
            is: [],
            homeWorks: nil,
            exam: nil,
            isOnlinePeriod: dict["isOnlinePeriod"] as? Bool,
            messengerChannel: nil,
            onlinePeriodLink: dict["onlinePeriodLink"] as? String,
            blockHash: dict["blockHash"] as? Int
        )
    }

    // MARK: - Period Details

    func getPeriodDetails(
        user: User,
        periodIds: Set<Int64>
    ) async throws -> [Period] {
        guard keychainManager.loadUserCredentials(userId: String(user.id)) != nil else {
            throw TimetableError.missingCredentials
        }

        // For now, return empty array since getPeriodData method doesn't exist yet
        // TODO: Implement getPeriodData method in UntisAPIClient when needed
        // The URLBuilder would be used here: try URLBuilder.buildApiUrl(apiHost: user.apiHost, schoolName: user.schoolName)
        return []
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

    // MARK: - Master Data Storage

    private func storeMasterData(_ masterDataDict: [String: Any], for user: User) throws {
        print("🔄 Storing master data for user \(user.id)")

        // Extract rooms from master data
        if let roomsArray = masterDataDict["rooms"] as? [[String: Any]] {
            print("📊 Found \(roomsArray.count) rooms in master data")

            let context = persistenceController.container.viewContext

            // Clear existing rooms for this user
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "RoomEntity")
            fetchRequest.predicate = NSPredicate(format: "userId == %lld", user.id)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(deleteRequest)
                print("✅ Cleared existing rooms for user")
            } catch {
                print("⚠️ Failed to clear existing rooms: \(error.localizedDescription)")
            }

            // Store new rooms
            for roomDict in roomsArray {
                guard let roomId = roomDict["id"] as? Int64,
                      let name = roomDict["name"] as? String else {
                    continue
                }

                let roomEntity = NSEntityDescription.entity(forEntityName: "RoomEntity", in: context)!
                let room = NSManagedObject(entity: roomEntity, insertInto: context)

                room.setValue(roomId, forKey: "id")
                room.setValue(name, forKey: "name")
                room.setValue(roomDict["longName"] as? String ?? name, forKey: "longName")
                room.setValue(roomDict["active"] as? Bool ?? true, forKey: "active")
                room.setValue(roomDict["building"] as? String, forKey: "building")
                room.setValue(user.id, forKey: "userId")
            }

            // Save the context
            do {
                try context.save()
                print("✅ Successfully stored \(roomsArray.count) rooms")
            } catch {
                print("❌ Failed to save rooms: \(error.localizedDescription)")
                throw TimetableError.cachingFailed
            }
        } else {
            print("📊 No rooms found in master data")
        }

        // TODO: Store other master data entities (subjects, teachers, etc.) if needed
    }

    // MARK: - Room Data Access

    func getRoomsFromMasterData(for user: User) -> [Room] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "RoomEntity")
        fetchRequest.predicate = NSPredicate(format: "userId == %lld AND active == true", user.id)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        do {
            let roomEntities = try context.fetch(fetchRequest)
            let rooms = roomEntities.compactMap { entity -> Room? in
                guard let id = entity.value(forKey: "id") as? Int64,
                      let name = entity.value(forKey: "name") as? String else {
                    return nil
                }

                return Room(
                    id: id,
                    name: name,
                    longName: entity.value(forKey: "longName") as? String ?? name,
                    active: entity.value(forKey: "active") as? Bool ?? true,
                    building: entity.value(forKey: "building") as? String
                )
            }

            print("📊 Retrieved \(rooms.count) rooms from master data for user \(user.id)")
            return rooms
        } catch {
            print("❌ Failed to fetch rooms from master data: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Supporting Types

enum TimetableError: Error, LocalizedError {
    case missingCredentials
    case invalidDateRange
    case noDataAvailable
    case serverTooOld(String)
    case cachingFailed

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "User credentials not found"
        case .invalidDateRange:
            return "Invalid date range specified"
        case .noDataAvailable:
            return "No timetable data available"
        case .serverTooOld(let message):
            return message
        case .cachingFailed:
            return "Failed to cache data"
        }
    }
}

// Core Data extensions for PeriodEntity - the entity class will be generated automatically
extension PeriodEntity {
    func toDomainModel() -> Period {
        return Period(
            id: self.id,
            lessonId: self.lessonId,
            startDateTime: self.startDateTime ?? Date(),
            endDateTime: self.endDateTime ?? Date(),
            foreColor: self.foreColor ?? "#000000",
            backColor: self.backColor ?? "#FFFFFF",
            innerForeColor: self.innerForeColor ?? "#000000",
            innerBackColor: self.innerBackColor ?? "#FFFFFF",
            text: PeriodText(
                lesson: self.lessonText,
                substitution: self.substitutionText,
                info: self.infoText
            ),
            elements: [], // TODO: Add relationship to elements if needed
            can: [],
            is: [],
            homeWorks: nil,
            exam: nil,
            isOnlinePeriod: false, // TODO: Add field to Core Data if needed
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
        self.innerForeColor = period.innerForeColor
        self.innerBackColor = period.innerBackColor
        self.lessonText = period.text.lesson
        self.substitutionText = period.text.substitution
        self.infoText = period.text.info
        self.userId = userId
    }
}