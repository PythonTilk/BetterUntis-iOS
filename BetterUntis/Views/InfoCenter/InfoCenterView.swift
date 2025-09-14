import SwiftUI

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
            Text(message.subject)
                .font(.headline)
                .foregroundColor(.primary)

            Text(message.text)
                .font(.body)
                .foregroundColor(.secondary)

            if message.isExpired {
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

                Text("Due: \(DateFormatter.shortDate.string(from: homework.dueDate))")
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
            Text(exam.name)
                .font(.headline)
                .foregroundColor(.primary)

            Text(exam.subject)
                .font(.subheadline)
                .foregroundColor(.blue)

            HStack {
                Label(DateFormatter.shortDate.string(from: exam.date), systemImage: "calendar")
                Spacer()
                Label("\(exam.startTime) - \(exam.endTime)", systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if !exam.text.isEmpty {
                Text(exam.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Absences List View (Placeholder)
struct AbsencesListView: View {
    let absences: [String] // Placeholder type

    var body: some View {
        emptyStateView("Absences", "Absence tracking coming soon", "person.crop.circle.badge.xmark")
    }
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
    @Published var absences: [String] = [] // Placeholder

    func loadMessages(for user: User) async throws {
        guard let credentials = keychainManager.loadUserCredentials(userId: String(user.id)) else {
            throw InfoCenterError.missingCredentials
        }

        let jsonRpcApiUrl = buildJsonRpcApiUrl(apiUrl: user.apiHost, schoolName: user.schoolName)
        let todayMessages = try await apiClient.getMessages(
            apiUrl: jsonRpcApiUrl,
            date: Date(),
            user: credentials.user,
            key: credentials.key
        )

        await MainActor.run {
            self.messages = todayMessages
        }
    }

    func loadHomework(for user: User) async throws {
        guard let credentials = keychainManager.loadUserCredentials(userId: String(user.id)) else {
            throw InfoCenterError.missingCredentials
        }

        let jsonRpcApiUrl = buildJsonRpcApiUrl(apiUrl: user.apiHost, schoolName: user.schoolName)
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!

        let homeworkList = try await apiClient.getHomework(
            apiUrl: jsonRpcApiUrl,
            startDate: startDate,
            endDate: endDate,
            user: credentials.user,
            key: credentials.key
        )

        await MainActor.run {
            self.homework = homeworkList.sorted { $0.dueDate < $1.dueDate }
        }
    }

    func loadExams(for user: User) async throws {
        guard let credentials = keychainManager.loadUserCredentials(userId: String(user.id)) else {
            throw InfoCenterError.missingCredentials
        }

        let jsonRpcApiUrl = buildJsonRpcApiUrl(apiUrl: user.apiHost, schoolName: user.schoolName)
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .month, value: 2, to: startDate)!

        let examsList = try await apiClient.getExams(
            apiUrl: jsonRpcApiUrl,
            startDate: startDate,
            endDate: endDate,
            user: credentials.user,
            key: credentials.key
        )

        await MainActor.run {
            self.exams = examsList.sorted { $0.date < $1.date }
        }
    }

    func loadAbsences(for user: User) async throws {
        // Placeholder implementation
        await MainActor.run {
            self.absences = []
        }
    }

    private func buildJsonRpcApiUrl(apiUrl: String, schoolName: String) -> String {
        var components = URLComponents(string: apiUrl)!
        if !components.path.contains("/WebUntis") {
            components.path += "/WebUntis"
        }
        components.path += "/jsonrpc_intern.do"
        components.queryItems = [URLQueryItem(name: "school", value: schoolName)]
        return components.url!.absoluteString
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