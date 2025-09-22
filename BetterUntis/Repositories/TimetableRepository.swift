import Foundation
import CoreData
import Combine

@MainActor
class TimetableRepository: ObservableObject {
    private let apiClient = UntisAPIClient()
    private let persistenceController = PersistenceController.shared
    private let keychainManager = KeychainManager.shared
    private var restClients: [Int64: UntisRESTClient] = [:]

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
        isLoading = true

        defer {
            isLoading = false
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
            if let _ = try await loadTimetableViaREST(
                for: user,
                credentials: credentials,
                startDate: startDate,
                endDate: endDate
            ) {
                return
            }
        } catch {
            print("⚠️ REST timetable fetch failed: \(error.localizedDescription)")
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

            self.currentTimetable = timetable
            self.lastUpdated = Date()

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

    private func loadTimetableViaREST(
        for user: User,
        credentials: UserCredentials,
        startDate: Date,
        endDate: Date
    ) async throws -> Timetable? {
        guard let personId = credentials.personId else {
            print("ℹ️ REST timetable requires personId; credentials missing this value")
            return nil
        }

        let restClient = restClient(for: user)
        guard restClient.isAuthenticated else {
            print("ℹ️ REST client has no token for user \(user.id); skipping REST timetable")
            return nil
        }

        let response = try await restClient.getTimetableEntries(
            resourceType: .student,
            resourceIds: [Int(personId)],
            startDate: startDate,
            endDate: endDate,
            cacheMode: .noCache,
            format: 1,
            periodTypes: nil,
            timetableType: .myTimetable,
            layout: .priority
        )

        let periods = restClient.convertTimetableEntriesToPeriods(
            response,
            resourceType: .student,
            primaryResourceId: Int(personId)
        )

        let timetable = Timetable(
            displayableStartDate: startDate,
            displayableEndDate: endDate,
            periods: periods
        )

        try cacheTimetable(timetable, for: user)
        currentTimetable = timetable
        lastUpdated = Date()
        print("📅 Loaded \(periods.count) periods via REST timetable entries")
        return timetable
    }

    private func restClient(for user: User) -> UntisRESTClient {
        if let existing = restClients[user.id] {
            return existing
        }

        let serverURL = buildServerURL(from: user.apiHost)
        let client = UntisRESTClient.create(
            for: serverURL,
            schoolName: user.schoolName,
            userIdentifier: String(user.id)
        )
        restClients[user.id] = client
        return client
    }

    private func buildServerURL(from apiHost: String) -> String {
        var normalized = apiHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return "https://webuntis.com"
        }
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        return normalized
    }

    private func parseTimetableFromDict(_ dict: [String: Any], startDate: Date, endDate: Date) throws -> Timetable {
        print("📊 Parsing timetable dictionary with keys: \(Array(dict.keys))")

        // Check for server compatibility message
        let serverMessage = dict["serverMessage"] as? String
        if let serverMessage {
            print("📋 Server message: \(serverMessage)")
        }

        // Prepare master data lookup for element resolution
        let masterDataIndex = buildMasterDataIndex(from: dict["masterData"] as? [String: Any])

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

        if let firstPeriod = periodsData.first,
           firstPeriod["date"] == nil,
           (firstPeriod["startDate"] != nil || firstPeriod["lessonNumber"] != nil) {
            print("⚠️ Detected lesson-definition fallback, reporting unsupported server")
            let message = serverMessage ?? "This WebUntis server version only provides legacy lesson data. Timetable loading is not supported."
            throw TimetableError.serverTooOld(message)
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
            if let period = try? parsePeriodFromDict(periodDict, dateFormatter: dateFormatter, masterData: masterDataIndex) {
                periods.append(period)
                print("📊 Successfully parsed period \(index + 1)")
            } else {
                print("⚠️ Failed to parse period \(index + 1)")
                // Try to create a basic period with available data
                if let basicPeriod = createBasicPeriodFromDict(periodDict, index: Int64(index), masterData: masterDataIndex) {
                    periods.append(basicPeriod)
                    print("📊 Created basic period \(index + 1)")
                }
            }
        }

        return Timetable(displayableStartDate: startDate, displayableEndDate: endDate, periods: periods)
    }

    private func parsePeriodFromDict(
        _ dict: [String: Any],
        dateFormatter: DateFormatter,
        masterData: MasterDataIndex?
    ) throws -> Period {
        guard let id = int64(from: dict["id"]),
              let date = normalizedDateString(from: dict["date"]),
              let startTime = normalizedTimeString(from: dict["startTime"]),
              let endTime = normalizedTimeString(from: dict["endTime"]) else {
            throw TimetableError.noDataAvailable
        }

        let lessonId = int64(from: dict["lessonId"]) ?? id

        // Parse date and times
        guard let baseDate = dateFormatter.date(from: date) else {
            throw TimetableError.noDataAvailable
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"

        let calendar = Calendar.current

        guard let startTimeDate = timeFormatter.date(from: startTime),
              let endTimeDate = timeFormatter.date(from: endTime) else {
            throw TimetableError.noDataAvailable
        }

        let startComponents = calendar.dateComponents([.hour, .minute], from: startTimeDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTimeDate)

        let startDateTime = calendar.date(bySettingHour: startComponents.hour ?? 0,
                                          minute: startComponents.minute ?? 0,
                                          second: 0,
                                          of: baseDate) ?? baseDate

        let endDateTime = calendar.date(bySettingHour: endComponents.hour ?? 0,
                                        minute: endComponents.minute ?? 0,
                                        second: 0,
                                        of: baseDate) ?? baseDate

        let subjects = periodElements(from: dict["su"], type: .subject, masterData: masterData)
        let teachers = periodElements(from: dict["te"], type: .teacher, masterData: masterData)
        let classes = periodElements(from: dict["kl"], type: .klasse, masterData: masterData)
        let rooms = periodElements(from: dict["ro"], type: .room, masterData: masterData)
        let allElements = classes + teachers + subjects + rooms

        let lessonTextValue = lessonTitle(subjectElements: subjects, periodDict: dict)
        let infoText = trimmed(dict["info"] as? String)

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
                lesson: lessonTextValue,
                substitution: nil,
                info: infoText
            ),
            elements: allElements,
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

    private func createBasicPeriodFromDict(
        _ dict: [String: Any],
        index: Int64,
        masterData: MasterDataIndex?
    ) -> Period? {
        print("📊 Attempting to create basic period from dict: \(dict)")

        // Try to extract basic information with flexible field names
        let id = int64(from: dict["id"]) ??
                 int64(from: dict["periodId"]) ??
                 int64(from: dict["lessonId"]) ??
                 index

        let lessonId = int64(from: dict["lessonId"]) ??
                       int64(from: dict["id"]) ??
                       index

        // Try different date/time field combinations
        var startDateTime = Date()
        var endDateTime = startDateTime.addingTimeInterval(3600)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        let calendar = Calendar.current

        if let dateString = normalizedDateString(from: dict["date"]) ?? normalizedDateString(from: dict["startDate"]),
           let baseDate = dateFormatter.date(from: dateString) {

            startDateTime = baseDate
            endDateTime = baseDate.addingTimeInterval(3600)

            if let startTimeString = normalizedTimeString(from: dict["startTime"]),
               let startTimeDate = timeFormatter.date(from: startTimeString) {
                let startComponents = calendar.dateComponents([.hour, .minute], from: startTimeDate)
                startDateTime = calendar.date(bySettingHour: startComponents.hour ?? 8,
                                              minute: startComponents.minute ?? 0,
                                              second: 0,
                                              of: baseDate) ?? baseDate
            }

            if let endTimeString = normalizedTimeString(from: dict["endTime"]),
               let endTimeDate = timeFormatter.date(from: endTimeString) {
                let endComponents = calendar.dateComponents([.hour, .minute], from: endTimeDate)
                endDateTime = calendar.date(bySettingHour: endComponents.hour ?? 9,
                                            minute: endComponents.minute ?? 0,
                                            second: 0,
                                            of: baseDate) ?? baseDate.addingTimeInterval(3600)
            }
        }

        let subjects = periodElements(from: dict["su"], type: .subject, masterData: masterData)
        let teachers = periodElements(from: dict["te"], type: .teacher, masterData: masterData)
        let classes = periodElements(from: dict["kl"], type: .klasse, masterData: masterData)
        let rooms = periodElements(from: dict["ro"], type: .room, masterData: masterData)
        let allElements = classes + teachers + subjects + rooms

        var lessonTextValue = lessonTitle(subjectElements: subjects, periodDict: dict) ?? "Course \(index + 1)"

        if let hpw = intValue(from: dict["hpw"]), hpw > 0 {
            lessonTextValue += " (\(hpw)h/week)"
        }

        let info = trimmed(dict["info"] as? String)

        print("📊 Creating basic period: id=\(id), lesson=\(lessonTextValue), start=\(startDateTime), end=\(endDateTime)")

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
                lesson: lessonTextValue,
                substitution: nil,
                info: info
            ),
            elements: allElements,
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

    // MARK: - Parsing Helpers

    private func int64(from value: Any?) -> Int64? {
        if let int64Value = value as? Int64 { return int64Value }
        if let intValue = value as? Int { return Int64(intValue) }
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String, let parsed = Int64(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        return nil
    }

    private func intValue(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let parsed = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        return nil
    }

    private func normalizedDateString(from value: Any?) -> String? {
        if let string = value as? String {
            let digits = string.filter { $0.isNumber }
            if digits.count == 8 { return digits }
            if let parsed = Int64(digits) {
                return String(format: "%08lld", parsed)
            }
        }

        if let number = value as? NSNumber {
            return String(format: "%08lld", number.int64Value)
        }

        if let int64Value = value as? Int64 {
            return String(format: "%08lld", int64Value)
        }

        if let intValue = value as? Int {
            return String(format: "%08d", intValue)
        }

        return nil
    }

    private func normalizedTimeString(from value: Any?) -> String? {
        if let string = value as? String {
            let digits = string.filter { $0.isNumber }
            guard !digits.isEmpty else { return nil }
            if let parsed = Int(digits) {
                return String(format: "%04d", parsed)
            }
        }

        if let number = value as? NSNumber {
            return String(format: "%04d", number.intValue)
        }

        if let int64Value = value as? Int64 {
            return String(format: "%04lld", int64Value)
        }

        if let intValue = value as? Int {
            return String(format: "%04d", intValue)
        }

        return nil
    }

    private func lessonTitle(subjectElements: [PeriodElement], periodDict: [String: Any]) -> String? {
        let subjectNames = subjectElements.map(elementDisplayName).filter { !$0.isEmpty }
        if !subjectNames.isEmpty {
            return subjectNames.joined(separator: ", ")
        }

        if let studentGroup = trimmed(periodDict["studentgroup"] as? String) {
            return studentGroup
        }

        if let activityType = trimmed(periodDict["activityType"] as? String) {
            return activityType
        }

        if let text = trimmed(periodDict["text"] as? String) {
            return text
        }

        return nil
    }

    private func periodElements(
        from rawValue: Any?,
        type: ElementType,
        masterData: MasterDataIndex?
    ) -> [PeriodElement] {
        if let dictionaries = rawValue as? [[String: Any]] {
            return dictionaries.compactMap { elementDict in
                guard let id = int64(from: elementDict["id"]) else { return nil }
                let entry = masterData?.entry(for: type, id: id)
                return makePeriodElement(id: id, type: type, dict: elementDict, masterEntry: entry)
            }
        }

        let ids: [Int64]
        if let rawIds = rawValue as? [Int64] {
            ids = rawIds
        } else if let rawInts = rawValue as? [Int] {
            ids = rawInts.map(Int64.init)
        } else if let rawStrings = rawValue as? [String] {
            ids = rawStrings.compactMap { Int64($0) }
        } else {
            return []
        }

        return ids.compactMap { id in
            let entry = masterData?.entry(for: type, id: id)
            return makePeriodElement(id: id, type: type, dict: nil, masterEntry: entry)
        }
    }

    private func makePeriodElement(
        id: Int64,
        type: ElementType,
        dict: [String: Any]?,
        masterEntry: MasterDataEntry?
    ) -> PeriodElement {
        let fallbackName = "#\(id)"
        let name = masterEntry?.name
            ?? trimmed(dict?["name"] as? String)
            ?? fallbackName
        let longName = masterEntry?.longName
            ?? trimmed(dict?["longName"] as? String ?? dict?["longname"] as? String)
        let displayName = masterEntry?.displayName
            ?? trimmed(dict?["displayName"] as? String ?? dict?["displayname"] as? String)
            ?? longName
            ?? name
        let alternateName = masterEntry?.alternateName
            ?? trimmed(dict?["shortName"] as? String ?? dict?["shortname"] as? String)
        let foreColor = masterEntry?.foreColor ?? stringValue(from: dict?["foreColor"])
        let backColor = masterEntry?.backColor ?? stringValue(from: dict?["backColor"])
        let canViewTimetable = masterEntry?.canViewTimetable ?? (dict?["canViewTimetable"] as? Bool)

        return PeriodElement(
            type: type,
            id: id,
            name: name,
            longName: longName ?? name,
            displayName: displayName,
            alternateName: alternateName,
            backColor: backColor,
            foreColor: foreColor,
            canViewTimetable: canViewTimetable
        )
    }

    private func buildMasterDataIndex(from masterDataDict: [String: Any]?) -> MasterDataIndex? {
        guard let masterDataDict else { return nil }
        var index = MasterDataIndex()

        if let classes = masterDataDict["klassen"] as? [[String: Any]] {
            for klass in classes {
                guard let entry = parseMasterDataEntry(type: .klasse, data: klass) else { continue }
                index.classes[entry.id] = entry
            }
        }

        if let teachers = masterDataDict["teachers"] as? [[String: Any]] {
            for teacher in teachers {
                guard let entry = parseMasterDataEntry(type: .teacher, data: teacher) else { continue }
                index.teachers[entry.id] = entry
            }
        }

        if let subjects = masterDataDict["subjects"] as? [[String: Any]] {
            for subject in subjects {
                guard let entry = parseMasterDataEntry(type: .subject, data: subject) else { continue }
                index.subjects[entry.id] = entry
            }
        }

        if let rooms = masterDataDict["rooms"] as? [[String: Any]] {
            for room in rooms {
                guard let entry = parseMasterDataEntry(type: .room, data: room) else { continue }
                index.rooms[entry.id] = entry
            }
        }

        return index.isEmpty ? nil : index
    }

    private func parseMasterDataEntry(type: ElementType, data: [String: Any]) -> MasterDataEntry? {
        guard let id = int64(from: data["id"]) else { return nil }

        let name = trimmed(data["name"] as? String) ?? "#\(id)"
        var longName = trimmed(data["longName"] as? String ?? data["longname"] as? String)
        var displayName = trimmed(data["displayName"] as? String ?? data["displayname"] as? String)
        let shortName = trimmed(data["shortName"] as? String ?? data["shortname"] as? String)

        if type == .teacher {
            let firstName = trimmed(data["firstName"] as? String ?? data["firstname"] as? String)
            let lastName = trimmed(data["lastName"] as? String ?? data["lastname"] as? String)
            let combined = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
            if !combined.isEmpty {
                longName = combined
                if displayName == nil {
                    displayName = combined
                }
            }
        }

        if displayName == nil {
            displayName = longName ?? name
        }

        let foreColor = stringValue(from: data["foreColor"])
        let backColor = stringValue(from: data["backColor"])
        let canViewTimetable = data["canViewTimetable"] as? Bool

        return MasterDataEntry(
            id: id,
            name: name,
            longName: longName,
            displayName: displayName,
            alternateName: shortName,
            foreColor: foreColor,
            backColor: backColor,
            canViewTimetable: canViewTimetable
        )
    }

    private func stringValue(from value: Any?) -> String? {
        if let string = value as? String { return trimmed(string) }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func elementDisplayName(_ element: PeriodElement) -> String {
        return element.displayName ?? element.longName
    }

    private func trimmed(_ string: String?) -> String? {
        guard let string = string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else {
            return nil
        }
        return string
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

private struct MasterDataEntry {
    let id: Int64
    let name: String
    let longName: String?
    let displayName: String?
    let alternateName: String?
    let foreColor: String?
    let backColor: String?
    let canViewTimetable: Bool?
}

private struct MasterDataIndex {
    var classes: [Int64: MasterDataEntry] = [:]
    var teachers: [Int64: MasterDataEntry] = [:]
    var subjects: [Int64: MasterDataEntry] = [:]
    var rooms: [Int64: MasterDataEntry] = [:]

    func entry(for type: ElementType, id: Int64) -> MasterDataEntry? {
        switch type {
        case .klasse:
            return classes[id]
        case .teacher:
            return teachers[id]
        case .subject:
            return subjects[id]
        case .room:
            return rooms[id]
        case .student:
            return nil
        }
    }

    var isEmpty: Bool {
        classes.isEmpty && teachers.isEmpty && subjects.isEmpty && rooms.isEmpty
    }
}

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
