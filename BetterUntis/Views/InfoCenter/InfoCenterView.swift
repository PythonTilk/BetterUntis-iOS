import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

struct InfoCenterView: View {
    @EnvironmentObject var userRepository: UserRepository
    @StateObject private var infoRepository = InfoCenterRepository()

    @State private var selectedTab: InfoTab = .messages
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    enum InfoTab: String, CaseIterable {
        case messages = "Messages"
        case homework = "Homework"
        case exams = "Exams"
        case absences = "Absences"

        var icon: String {
            switch self {
            case .messages: return "envelope"
            case .homework: return "book"
            case .exams: return "doc.text"
            case .absences: return "person.crop.circle.badge.xmark"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                tabSelector

                // Content
                Group {
                    if isLoading {
                        loadingView
                    } else {
                        contentView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Error message
                if let errorMessage = errorMessage {
                    errorView(errorMessage)
                }
            }
            .navigationTitle("Info Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            loadDataForSelectedTab()
        }
        .onChange(of: selectedTab) { _, _ in
            loadDataForSelectedTab()
        }
        .onChange(of: userRepository.currentUser) { _, _ in
            loadDataForSelectedTab()
        }
    }

    // MARK: - Tab Selector
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(InfoTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18))

                            Text(tab.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(selectedTab == tab ? .blue : .secondary)
                        .frame(width: 80, height: 60)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGray6))
    }

    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .messages:
            MessagesListView(messages: infoRepository.messages)
        case .homework:
            HomeworkListView(homework: infoRepository.homework)
        case .exams:
            ExamsListView(exams: infoRepository.exams)
        case .absences:
            AbsencesListView(absences: infoRepository.absences)
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading \(selectedTab.rawValue.lowercased())...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()

            Button("Dismiss") {
                errorMessage = nil
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Methods
    private func loadDataForSelectedTab() {
        guard let user = userRepository.currentUser else { return }

        errorMessage = nil

        Task {
            await MainActor.run {
                isLoading = true
            }

            do {
                switch selectedTab {
                case .messages:
                    try await infoRepository.loadMessages(for: user)
                case .homework:
                    try await infoRepository.loadHomework(for: user)
                case .exams:
                    try await infoRepository.loadExams(for: user)
                case .absences:
                    try await infoRepository.loadAbsences(for: user)
                }

                await MainActor.run {
                    isLoading = false
                }

            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to load \(selectedTab.rawValue.lowercased()): \(error.localizedDescription)"
                }
            }
        }
    }

    private func refreshData() {
        loadDataForSelectedTab()
    }
}

// MARK: - Messages List View
struct MessagesListView: View {
    let messages: [MessageOfDay]

    var body: some View {
        Group {
            if messages.isEmpty {
                emptyStateView("No Messages", "No messages for today", "envelope.badge")
            } else {
                List(messages, id: \.id) { message in
                    MessageRowView(message: message)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

struct MessageRowView: View {
    let message: MessageOfDay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.subject ?? "No Subject")
                .font(.headline)
                .foregroundColor(.primary)

            Text(message.text ?? "No Content")
                .font(.body)
                .foregroundColor(.secondary)

            if message.isExpired == true {
                Label("Expired", systemImage: "clock.badge.xmark")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Homework List View
struct HomeworkListView: View {
    let homework: [HomeWork]

    var body: some View {
        Group {
            if homework.isEmpty {
                emptyStateView("No Homework", "No assignments found", "book")
            } else {
                List(homework, id: \.id) { assignment in
                    HomeworkRowView(homework: assignment)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

struct HomeworkRowView: View {
    let homework: HomeWork

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(homework.text)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .strikethrough(homework.completed)

                Text("Due: \(DateFormatter.shortDate.string(from: homework.endDate))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let remark = homework.remark, !remark.isEmpty {
                    Text(remark)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            if homework.completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Exams List View
struct ExamsListView: View {
    let exams: [Exam]

    var body: some View {
        Group {
            if exams.isEmpty {
                emptyStateView("No Exams", "No upcoming exams", "doc.text")
            } else {
                List(exams, id: \.id) { exam in
                    ExamRowView(exam: exam)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

struct ExamRowView: View {
    let exam: Exam

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exam.name ?? "No Name")
                .font(.headline)
                .foregroundColor(.primary)

            Text(exam.subject ?? "No Subject")
                .font(.subheadline)
                .foregroundColor(.blue)

            HStack {
                Label(DateFormatter.shortDate.string(from: exam.date), systemImage: "calendar")
                Spacer()
                Label("\(exam.startTime ?? "?") - \(exam.endTime ?? "?")", systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if let examText = exam.text, !examText.isEmpty {
                Text(examText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Absences List View
struct AbsencesListView: View {
    let absences: [AbsenceRecord]

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }

    var body: some View {
        if absences.isEmpty {
            emptyStateView(
                "Absences",
                "No recorded absences for the selected period",
                "person.crop.circle.badge.xmark"
            )
        } else {
            List(absences) { absence in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(absence.startDateTime, formatter: DateFormatter.shortDate)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(timeFormatter.string(from: absence.startDateTime))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !Calendar.current.isDate(absence.startDateTime, inSameDayAs: absence.endDateTime) {
                            Text("→")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(absence.endDateTime, formatter: DateFormatter.shortDate)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(timeFormatter.string(from: absence.endDateTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("– \(timeFormatter.string(from: absence.endDateTime))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if let excused = absence.excused {
                            Text(excused ? "Excused" : "Unexcused")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background((excused ? Color.green : Color.red).opacity(0.15))
                                .foregroundColor(excused ? .green : .red)
                                .cornerRadius(6)
                        }
                    }

                    if let reason = absence.reason, !reason.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text(reason)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let description = absence.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let klasse = absence.className, !klasse.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person.3")
                                .foregroundColor(.secondary)
                            Text(klasse)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .listStyle(.insetGrouped)
        }
    }
}

struct AbsenceRecord: Identifiable, Sendable {
    let id: Int64
    let startDateTime: Date
    let endDateTime: Date
    let excused: Bool?
    let reason: String?
    let description: String?
    let className: String?
}

// MARK: - Empty State View
private func emptyStateView(_ title: String, _ subtitle: String, _ iconName: String) -> some View {
    VStack(spacing: 20) {
        Image(systemName: iconName)
            .font(.system(size: 50))
            .foregroundColor(.gray)

        VStack(spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.medium)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
}

// MARK: - Info Center Repository
class InfoCenterRepository: ObservableObject {
    private let apiClient = UntisAPIClient()
    private let keychainManager = KeychainManager.shared

    @Published var messages: [MessageOfDay] = []
    @Published var homework: [HomeWork] = []
    @Published var exams: [Exam] = []
    @Published var absences: [AbsenceRecord] = []

    func loadMessages(for user: User) async throws {
        guard let credentials = keychainManager.loadUserCredentials(userId: String(user.id)) else {
            throw InfoCenterError.missingCredentials
        }

        // Use URLBuilder for robust URL construction with fallback support
        let apiUrls = try URLBuilder.buildApiUrlsWithFallback(
            apiHost: user.apiHost,
            schoolName: user.schoolName
        )

        var lastError: Error?
        var todayMessagesDicts: [[String: Any]]?

        // Try each URL until one works
        for apiUrl in apiUrls {
            do {
                print("🔄 Trying messages API URL: \(apiUrl)")
                todayMessagesDicts = try await apiClient.getMessagesOfDay(
                    apiUrl: apiUrl,
                    date: Date(),
                    user: credentials.user,
                    key: credentials.key
                )
                print("✅ Messages loaded successfully with URL: \(apiUrl)")
                break
            } catch {
                print("❌ Messages failed with URL \(apiUrl): \(error.localizedDescription)")
                lastError = error
                continue
            }
        }

        guard let messageDicts = todayMessagesDicts else {
            throw lastError ?? InfoCenterError.missingCredentials
        }

        let todayMessages = parseMessages(messageDicts)


    func parseMessages(_ dicts: [[String: Any]]) -> [MessageOfDay] {
        dicts.compactMap { dict in
            guard let id = int64Value(dict["id"]) else { return nil }
            let subject = stringValue(dict["subject"]) ?? stringValue(dict["title"])
            let text = stringValue(dict["text"]) ?? stringValue(dict["message"]) ?? stringValue(dict["content"])
            let isExpired = boolValue(dict["isExpired"]) ?? boolValue(dict["expired"])
            let isImportant = boolValue(dict["isImportant"]) ?? boolValue(dict["priority"])
            let attachmentsArray = dict["attachments"] as? [[String: Any]] ?? dict["files"] as? [[String: Any]] ?? []
            let attachments = attachmentsArray.compactMap(parseMessageAttachment)

            return MessageOfDay(
                id: id,
                subject: subject,
                text: text,
                isExpired: isExpired,
                isImportant: isImportant,
                attachments: attachments.isEmpty ? nil : attachments
            )
        }
    }

    func parseHomework(_ dicts: [[String: Any]]) -> [HomeWork] {
        dicts.compactMap { dict in
            guard let id = intValue(dict["id"] ?? dict["homeworkId"]) else { return nil }
            guard let startDate = dateValue(dict["date"] ?? dict["startDate"]) else { return nil }
            guard let endDate = dateValue(dict["dueDate"] ?? dict["endDate"]) else { return nil }

            let text = stringValue(dict["text"]) ?? stringValue(dict["title"]) ?? "Homework"
            let remark = stringValue(dict["remark"] ?? dict["description"] ?? dict["details"])
            let completed = boolValue(dict["completed"]) ?? boolValue(dict["done"]) ?? false
            let lastUpdate = dateValue(dict["lastUpdate"] ?? dict["updatedAt"] ?? dict["lastChangeDate"])
            let attachmentsArray = dict["attachments"] as? [[String: Any]] ?? dict["files"] as? [[String: Any]] ?? []
            let attachments = attachmentsArray.compactMap(parseHomeworkAttachment)

            return HomeWork(
                id: id,
                lessonId: intValue(dict["lessonId"]),
                subjectId: intValue(dict["subjectId"]),
                teacherId: intValue(dict["teacherId"]),
                startDate: startDate,
                endDate: endDate,
                text: text,
                remark: remark,
                completed: completed,
                attachments: attachments,
                lastUpdate: lastUpdate
            )
        }
    }

    func parseExams(_ dicts: [[String: Any]]) -> [Exam] {
        dicts.compactMap { dict in
            guard let id = int64Value(dict["id"]) else { return nil }
            guard let date = dateValue(dict["date"]) else { return nil }

            let classes = parseExamClasses(from: dict["klassen"] ?? dict["classes"])
            let teachers = parseExamTeachers(from: dict["teachers"])
            let students = parseExamStudents(from: dict["students"])
            let rooms = parseExamRooms(from: dict["rooms"])

            let subject: String?
            if let subjectDict = dict["subject"] as? [String: Any] {
                subject = stringValue(subjectDict["displayName"]) ?? stringValue(subjectDict["name"]) ?? stringValue(subjectDict["longName"])
            } else {
                subject = stringValue(dict["subject"])
            }

            let text = stringValue(dict["text"]) ?? stringValue(dict["remark"])
            let examType = stringValue(dict["examType"] ?? dict["type"])
            let name = stringValue(dict["name"] ?? dict["title"])

            return Exam(
                id: id,
                classes: classes,
                teachers: teachers,
                students: students,
                subject: subject,
                date: date,
                startTime: formattedTimeString(from: dict["startTime"] ?? dict["start"]),
                endTime: formattedTimeString(from: dict["endTime"] ?? dict["end"]),
                rooms: rooms.isEmpty ? nil : rooms,
                text: text,
                examType: examType,
                name: name
            )
        }
    }

        await MainActor.run {
            self.messages = todayMessages
        }
    }

    func loadHomework(for user: User) async throws {
        guard let credentials = keychainManager.loadUserCredentials(userId: String(user.id)) else {
            throw InfoCenterError.missingCredentials
        }

        // Use URLBuilder for robust URL construction with fallback support
        let apiUrls = try URLBuilder.buildApiUrlsWithFallback(
            apiHost: user.apiHost,
            schoolName: user.schoolName
        )

        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!

        var lastError: Error?
        var homeworkDicts: [[String: Any]]?

        // Try each URL until one works
        for apiUrl in apiUrls {
            do {
                print("🔄 Trying homework API URL: \(apiUrl)")
                homeworkDicts = try await apiClient.getHomeWork(
                    apiUrl: apiUrl,
                    startDate: startDate,
                    endDate: endDate,
                    user: credentials.user,
                    key: credentials.key
                )
                print("✅ Homework loaded successfully with URL: \(apiUrl)")
                break
            } catch {
                print("❌ Homework failed with URL \(apiUrl): \(error.localizedDescription)")
                lastError = error
                continue
            }
        }

        guard let hwDicts = homeworkDicts else {
            throw lastError ?? InfoCenterError.missingCredentials
        }

        let homeworkList = parseHomework(hwDicts)

        await MainActor.run {
            self.homework = homeworkList.sorted { $0.endDate < $1.endDate }
        }
    }

    func loadExams(for user: User) async throws {
        guard let credentials = keychainManager.loadUserCredentials(userId: String(user.id)) else {
            throw InfoCenterError.missingCredentials
        }

        // Use URLBuilder for robust URL construction with fallback support
        let apiUrls = try URLBuilder.buildApiUrlsWithFallback(
            apiHost: user.apiHost,
            schoolName: user.schoolName
        )

        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .month, value: 2, to: startDate)!

        var lastError: Error?
        var examsDicts: [[String: Any]]?

        // Try each URL until one works
        for apiUrl in apiUrls {
            do {
                print("🔄 Trying exams API URL: \(apiUrl)")
                examsDicts = try await apiClient.getExams(
                    apiUrl: apiUrl,
                    startDate: startDate,
                    endDate: endDate,
                    user: credentials.user,
                    key: credentials.key
                )
                print("✅ Exams loaded successfully with URL: \(apiUrl)")
                break
            } catch {
                print("❌ Exams failed with URL \(apiUrl): \(error.localizedDescription)")
                lastError = error
                continue
            }
        }

        guard let examDicts = examsDicts else {
            throw lastError ?? InfoCenterError.missingCredentials
        }

        let examsList = parseExams(examDicts)

        await MainActor.run {
            self.exams = examsList.sorted { $0.date < $1.date }
        }
    }

    func loadAbsences(for user: User) async throws {
        guard let credentials = keychainManager.loadUserCredentials(userId: String(user.id)) else {
            throw InfoCenterError.missingCredentials
        }

        let apiUrls = try URLBuilder.buildApiUrlsWithFallback(
            apiHost: user.apiHost,
            schoolName: user.schoolName
        )

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()

        var lastError: Error?
        var absencesDicts: [[String: Any]]?

        for apiUrl in apiUrls {
            do {
                print("🔄 Trying absences API URL: \(apiUrl)")
                absencesDicts = try await apiClient.getStudentAbsences(
                    apiUrl: apiUrl,
                    startDate: startDate,
                    endDate: endDate,
                    user: credentials.user,
                    key: credentials.key
                )
                print("✅ Absences loaded successfully with URL: \(apiUrl)")
                break
            } catch {
                lastError = error
                print("❌ Absences failed with URL \(apiUrl): \(error.localizedDescription)")
                continue
            }
        }

        guard let absenceDicts = absencesDicts else {
            throw lastError ?? InfoCenterError.missingCredentials
        }

        let records = absenceDicts.compactMap(parseAbsenceRecord)

        await MainActor.run {
            self.absences = records.sorted { $0.startDateTime > $1.startDateTime }
        }
    }

    // MARK: - Parsing Helpers

    func parseAbsenceRecord(from dict: [String: Any]) -> AbsenceRecord? {
        guard let id = int64Value(dict["id"]) ?? int64Value(dict["absenceId"]) else { return nil }

        guard let startDate = dateValue(dict["startDate"] ?? dict["date"]),
              let endDate = dateValue(dict["endDate"] ?? dict["date"]) else {
            return nil
        }

        let startDateTime = combine(date: startDate, timeValue: dict["startTime"] ?? dict["from"])
        let endDateTime = combine(date: endDate, timeValue: dict["endTime"] ?? dict["to"])

        let excused = boolValue(dict["isExcused"]) ?? boolValue(dict["excused"])
        let reason = stringValue(dict["reason"]) ?? stringValue(dict["absenceReason"]) ?? stringValue(dict["reasonText"])
        let description = stringValue(dict["text"]) ?? stringValue(dict["longText"]) ?? stringValue(dict["remark"])

        var className: String?
        if let klasseDict = dict["klasse"] as? [String: Any] {
            className = stringValue(klasseDict["displayName"]) ?? stringValue(klasseDict["name"])
        } else if let klasseName = stringValue(dict["klasse"] ?? dict["class"]) {
            className = klasseName
        }

        return AbsenceRecord(
            id: id,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            excused: excused,
            reason: reason,
            description: description,
            className: className
        )
    }

    func parseMessages(_ dicts: [[String: Any]]) -> [MessageOfDay] {
        dicts.compactMap { dict in
            guard let id = int64Value(dict["id"]) else { return nil }
            let subject = stringValue(dict["subject"]) ?? stringValue(dict["title"])
            let text = stringValue(dict["text"]) ?? stringValue(dict["message"]) ?? stringValue(dict["content"])
            let isExpired = boolValue(dict["isExpired"]) ?? boolValue(dict["expired"])
            let isImportant = boolValue(dict["isImportant"]) ?? boolValue(dict["priority"])
            let attachmentsArray = dict["attachments"] as? [[String: Any]] ?? dict["files"] as? [[String: Any]] ?? []
            let attachments = attachmentsArray.compactMap(parseMessageAttachment)

            return MessageOfDay(
                id: id,
                subject: subject,
                text: text,
                isExpired: isExpired,
                isImportant: isImportant,
                attachments: attachments.isEmpty ? nil : attachments
            )
        }
    }

    func parseHomework(_ dicts: [[String: Any]]) -> [HomeWork] {
        dicts.compactMap { dict in
            guard let id = intValue(dict["id"] ?? dict["homeworkId"]) else { return nil }
            guard let startDate = dateValue(dict["date"] ?? dict["startDate"]) else { return nil }
            guard let endDate = dateValue(dict["dueDate"] ?? dict["endDate"]) else { return nil }

            let text = stringValue(dict["text"]) ?? stringValue(dict["title"]) ?? "Homework"
            let remark = stringValue(dict["remark"] ?? dict["description"] ?? dict["details"])
            let completed = boolValue(dict["completed"]) ?? boolValue(dict["done"]) ?? false
            let lastUpdate = dateValue(dict["lastUpdate"] ?? dict["updatedAt"] ?? dict["lastChangeDate"])
            let attachmentsArray = dict["attachments"] as? [[String: Any]] ?? dict["files"] as? [[String: Any]] ?? []
            let attachments = attachmentsArray.compactMap(parseHomeworkAttachment)

            return HomeWork(
                id: id,
                lessonId: intValue(dict["lessonId"]),
                subjectId: intValue(dict["subjectId"]),
                teacherId: intValue(dict["teacherId"]),
                startDate: startDate,
                endDate: endDate,
                text: text,
                remark: remark,
                completed: completed,
                attachments: attachments,
                lastUpdate: lastUpdate
            )
        }
    }

    func parseExams(_ dicts: [[String: Any]]) -> [Exam] {
        dicts.compactMap { dict in
            guard let id = int64Value(dict["id"]) else { return nil }
            guard let date = dateValue(dict["date"]) else { return nil }

            let classes = parseExamClasses(from: dict["klassen"] ?? dict["classes"])
            let teachers = parseExamTeachers(from: dict["teachers"])
            let students = parseExamStudents(from: dict["students"])
            let rooms = parseExamRooms(from: dict["rooms"])

            let subject: String?
            if let subjectDict = dict["subject"] as? [String: Any] {
                subject = stringValue(subjectDict["displayName"]) ?? stringValue(subjectDict["name"]) ?? stringValue(subjectDict["longName"])
            } else {
                subject = stringValue(dict["subject"])
            }

            let text = stringValue(dict["text"]) ?? stringValue(dict["remark"])
            let examType = stringValue(dict["examType"] ?? dict["type"])
            let name = stringValue(dict["name"] ?? dict["title"])

            return Exam(
                id: id,
                classes: classes,
                teachers: teachers,
                students: students,
                subject: subject,
                date: date,
                startTime: formattedTimeString(from: dict["startTime"] ?? dict["start"]),
                endTime: formattedTimeString(from: dict["endTime"] ?? dict["end"]),
                rooms: rooms.isEmpty ? nil : rooms,
                text: text,
                examType: examType,
                name: name
            )
        }
    }

    func parseMessageAttachment(from dict: [String: Any]) -> MessageAttachment? {
        guard let id = int64Value(dict["id"]) else { return nil }
        let name = stringValue(dict["name"]) ?? "Attachment \(id)"
        let url = stringValue(dict["url"]) ?? stringValue(dict["downloadUrl"]) ?? stringValue(dict["fileUrl"])
        return MessageAttachment(id: id, name: name, url: url)
    }

    func parseHomeworkAttachment(from dict: [String: Any]) -> HomeworkAttachment? {
        guard let id = intValue(dict["id"]) else { return nil }
        let name = stringValue(dict["name"]) ?? "Attachment \(id)"
        let url = stringValue(dict["url"]) ?? stringValue(dict["downloadUrl"]) ?? stringValue(dict["fileUrl"])
        let fileSize = intValue(dict["fileSize"]) ?? intValue(dict["size"])
        let mimeType = stringValue(dict["mimeType"]) ?? stringValue(dict["contentType"])
        let uploadDate = dateValue(dict["uploadDate"])

        return HomeworkAttachment(
            id: id,
            name: name,
            url: url,
            fileSize: fileSize,
            mimeType: mimeType,
            uploadDate: uploadDate
        )
    }

    func parseExamClasses(from value: Any?) -> [ExamClass] {
        guard let array = value as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let id = int64Value(dict["id"]) else { return nil }
            let name = stringValue(dict["name"]) ?? "Class \(id)"
            let longName = stringValue(dict["longName"] ?? dict["longname"]) ?? name
            return ExamClass(id: id, name: name, longName: longName)
        }
    }

    func parseExamTeachers(from value: Any?) -> [ExamTeacher] {
        guard let array = value as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let id = int64Value(dict["id"]) else { return nil }
            let name = stringValue(dict["name"]) ?? "Teacher \(id)"
            let longName = stringValue(dict["longName"] ?? dict["longname"]) ?? name
            return ExamTeacher(id: id, name: name, longName: longName)
        }
    }

    func parseExamStudents(from value: Any?) -> [ExamStudent] {
        guard let array = value as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let id = int64Value(dict["id"]) else { return nil }
            let key = stringValue(dict["key"]) ?? "#\(id)"
            let name = stringValue(dict["name"]) ?? key
            let foreName = stringValue(dict["foreName"] ?? dict["forename"]) ?? ""
            let longName = stringValue(dict["longName"] ?? dict["longname"]) ?? name
            return ExamStudent(id: id, key: key, name: name, foreName: foreName, longName: longName)
        }
    }

    func parseExamRooms(from value: Any?) -> [ExamRoom] {
        guard let array = value as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let id = int64Value(dict["id"]) else { return nil }
            let name = stringValue(dict["name"]) ?? "Room \(id)"
            let longName = stringValue(dict["longName"] ?? dict["longname"]) ?? name
            return ExamRoom(id: id, name: name, longName: longName)
        }
    }

    func int64Value(_ value: Any?) -> Int64? {
        if let int64 = value as? Int64 { return int64 }
        if let intValue = value as? Int { return Int64(intValue) }
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String, let parsed = Int64(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        return nil
    }

    func intValue(_ value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let parsed = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        return nil
    }

    func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            let lower = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "yes", "y"].contains(lower) { return true }
            if ["0", "false", "no", "n"].contains(lower) { return false }
        }
        return nil
    }

    func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    func dateValue(_ value: Any?) -> Date? {
        if let date = value as? Date { return date }

        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let date = DateFormatter.untisDateTime.date(from: trimmed) {
                return date
            }
            if let date = DateFormatter.untisDateTimeMinutes.date(from: trimmed) {
                return date
            }
            if let date = DateFormatter.untisDate.date(from: trimmed) {
                return date
            }
            if let isoDate = ISO8601DateFormatter().date(from: trimmed) {
                return isoDate
            }
            if let digits = normalizedDateString(from: trimmed),
               let hyphenated = hyphenatedDateString(from: digits),
               let date = DateFormatter.untisDate.date(from: hyphenated) {
                return date
            }
        }

        if let number = value as? NSNumber {
            let digits = String(format: "%08lld", number.int64Value)
            if let hyphenated = hyphenatedDateString(from: digits) {
                return DateFormatter.untisDate.date(from: hyphenated)
            }
        }
        if let intValue = value as? Int {
            let digits = String(format: "%08d", intValue)
            if let hyphenated = hyphenatedDateString(from: digits) {
                return DateFormatter.untisDate.date(from: hyphenated)
            }
        }

        return nil
    }

    func combine(date: Date, timeValue: Any?) -> Date {
        guard let timeString = normalizedTimeString(from: timeValue) else { return date }
        let hour = Int(timeString.prefix(2)) ?? 0
        let minute = Int(timeString.suffix(2)) ?? 0
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    func normalizedDateString(from value: Any?) -> String? {
        if let string = value as? String {
            let digits = string.filter { $0.isNumber }
            guard !digits.isEmpty else { return nil }
            if digits.count == 8 { return digits }
            if let parsed = Int64(digits) {
                return String(format: "%08lld", parsed)
            }
        }
        if let number = value as? NSNumber {
            return String(format: "%08lld", number.int64Value)
        }
        if let intValue = value as? Int {
            return String(format: "%08d", intValue)
        }
        return nil
    }

    func hyphenatedDateString(from digits: String) -> String? {
        guard digits.count == 8 else { return nil }
        let year = digits.prefix(4)
        let month = digits.dropFirst(4).prefix(2)
        let day = digits.suffix(2)
        return "\(year)-\(month)-\(day)"
    }

    func normalizedTimeString(from value: Any?) -> String? {
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
        if let intValue = value as? Int {
            return String(format: "%04d", intValue)
        }
        return nil
    }

    func formattedTimeString(from value: Any?) -> String? {
        guard let normalized = normalizedTimeString(from: value) else { return nil }
        let hours = normalized.prefix(2)
        let minutes = normalized.suffix(2)
        return "\(String(hours)):\(String(minutes))"
    }


}

enum InfoCenterError: Error, LocalizedError {
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "User credentials not found"
        }
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    InfoCenterView()
        .environmentObject(UserRepository())
}
