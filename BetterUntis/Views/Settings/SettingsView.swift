import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userRepository: UserRepository
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("autoRefresh") private var autoRefresh = true

    @State private var showingAccountManagement = false
    @State private var showingAbout = false
    @State private var showingLogoutConfirmation = false

    var body: some View {
        NavigationView {
            List {
                // Current User Section
                if let user = userRepository.currentUser {
                    currentUserSection(user)
                }

                // Account Management Section
                accountManagementSection

                // App Settings Section
                appSettingsSection

                // About Section
                aboutSection

                // Advanced Section
                advancedSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAccountManagement) {
                AccountManagementView()
                    .environmentObject(userRepository)
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .alert("Logout", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    userRepository.logout()
                }
            } message: {
                Text("Are you sure you want to logout? You will need to login again to access your timetable.")
            }
        }
    }

    // MARK: - Current User Section
    private func currentUserSection(_ user: User) -> some View {
        Section {
            HStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(user.getDisplayedName().prefix(1).uppercased()))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.getDisplayedName())
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(user.schoolName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if user.anonymous {
                        Label("Guest Account", systemImage: "person.crop.circle.dashed")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
        } header: {
            Text("Account")
        }
    }

    // MARK: - Account Management Section
    private var accountManagementSection: some View {
        Section {
            Button(action: { showingAccountManagement = true }) {
                Label("Manage Accounts", systemImage: "person.2")
                    .foregroundColor(.primary)
            }

            Button(action: { showingLogoutConfirmation = true }) {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - App Settings Section
    private var appSettingsSection: some View {
        Section {
            // Dark Mode Toggle
            HStack {
                Label("Dark Mode", systemImage: "moon")
                Spacer()
                Toggle("", isOn: $isDarkMode)
            }

            // Notifications Toggle
            HStack {
                Label("Notifications", systemImage: "bell")
                Spacer()
                Toggle("", isOn: $showNotifications)
            }

            // Auto Refresh Toggle
            HStack {
                Label("Auto Refresh", systemImage: "arrow.clockwise")
                Spacer()
                Toggle("", isOn: $autoRefresh)
            }

            // Time Format (placeholder)
            NavigationLink(destination: TimeFormatSettingsView()) {
                Label("Time Format", systemImage: "clock")
            }

        } header: {
            Text("App Settings")
        } footer: {
            Text("Enable notifications to receive break reminders and timetable updates.")
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        Section {
            Button(action: { showingAbout = true }) {
                Label("About BetterUntis", systemImage: "info.circle")
                    .foregroundColor(.primary)
            }

            Link(destination: URL(string: "https://github.com/SapuSeven/BetterUntis")!) {
                Label("Source Code", systemImage: "curlybraces")
                    .foregroundColor(.primary)
            }

            NavigationLink(destination: PrivacyPolicyView()) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

        } header: {
            Text("About")
        }
    }

    // MARK: - Advanced Section
    private var advancedSection: some View {
        Section {
            NavigationLink(destination: CacheManagementView()) {
                Label("Cache Management", systemImage: "externaldrive")
            }

            NavigationLink(destination: ExportSettingsView()) {
                Label("Export Settings", systemImage: "square.and.arrow.up")
            }

            Button(action: clearCache) {
                Label("Clear Cache", systemImage: "trash")
                    .foregroundColor(.red)
            }

        } header: {
            Text("Advanced")
        } footer: {
            Text("Clear cache will remove all offline timetable data. You may need to refresh your timetable after clearing cache.")
        }
    }

    // MARK: - Methods
    private func clearCache() {
        // Implementation would clear Core Data cache
        // For now, just a placeholder
    }
}

// MARK: - Account Management View
struct AccountManagementView: View {
    @EnvironmentObject var userRepository: UserRepository
    @Environment(\.presentationMode) var presentationMode

    @State private var showingAddAccount = false
    @State private var userToDelete: User?

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(userRepository.getAllUsers(), id: \.id) { user in
                        UserRowView(
                            user: user,
                            isCurrentUser: user.id == userRepository.currentUser?.id,
                            onSwitch: {
                                userRepository.switchToUser(user)
                                presentationMode.wrappedValue.dismiss()
                            },
                            onDelete: {
                                userToDelete = user
                            }
                        )
                    }
                } header: {
                    Text("Accounts")
                } footer: {
                    Text("Switch between different Untis accounts. The active account is highlighted.")
                }

                Section {
                    Button(action: { showingAddAccount = true }) {
                        Label("Add Account", systemImage: "plus")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Account Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            LoginView()
                .environmentObject(userRepository)
        }
        .alert("Delete Account", isPresented: Binding(
            get: { userToDelete != nil },
            set: { if !$0 { userToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                userToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let user = userToDelete {
                    try? userRepository.deleteUser(user)
                    userToDelete = nil
                }
            }
        } message: {
            if let user = userToDelete {
                Text("Are you sure you want to delete the account for \(user.getDisplayedName())? This action cannot be undone.")
            }
        }
    }
}

// MARK: - User Row View
struct UserRowView: View {
    let user: User
    let isCurrentUser: Bool
    let onSwitch: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            // User avatar
            Circle()
                .fill(isCurrentUser ? Color.blue : Color.gray)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(user.getDisplayedName().prefix(1).uppercased()))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                )

            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.getDisplayedName())
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(user.schoolName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if user.anonymous {
                    Text("Guest Account")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Current user indicator
            if isCurrentUser {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isCurrentUser {
                onSwitch()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isCurrentUser {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Placeholder Views
struct TimeFormatSettingsView: View {
    @AppStorage("use24HourFormat") private var use24HourFormat = true

    var body: some View {
        List {
            Section {
                HStack {
                    Text("24-Hour Format")
                    Spacer()
                    Toggle("", isOn: $use24HourFormat)
                }
            } footer: {
                Text("Choose whether to display times in 12-hour or 24-hour format.")
            }
        }
        .navigationTitle("Time Format")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("BetterUntis respects your privacy and is committed to protecting your personal data.")

                Text("Data Collection")
                    .font(.headline)

                Text("We only collect the data necessary to provide the timetable service, including your login credentials and timetable data from your school's Untis system.")

                Text("Data Storage")
                    .font(.headline)

                Text("All data is stored securely on your device and in your school's Untis system. We do not store your data on external servers.")

                Text("Contact")
                    .font(.headline)

                Text("If you have any questions about this privacy policy, please contact us through our GitHub repository.")

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CacheManagementView: View {
    @State private var cacheSize = "Loading..."

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(cacheSize)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("Cached data includes timetables, master data, and other information downloaded from your school's Untis system.")
            }
        }
        .navigationTitle("Cache Management")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateCacheSize()
        }
    }

    private func calculateCacheSize() {
        // Placeholder implementation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cacheSize = "2.3 MB"
        }
    }
}

struct ExportSettingsView: View {
    var body: some View {
        List {
            Section {
                Button(action: exportToCalendar) {
                    Label("Export to Calendar", systemImage: "calendar.badge.plus")
                        .foregroundColor(.blue)
                }

                Button(action: exportToPDF) {
                    Label("Export as PDF", systemImage: "doc.pdf")
                        .foregroundColor(.blue)
                }

            } header: {
                Text("Export Options")
            } footer: {
                Text("Export your timetable to other apps or as a PDF document.")
            }
        }
        .navigationTitle("Export")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exportToCalendar() {
        // Placeholder for calendar export
    }

    private func exportToPDF() {
        // Placeholder for PDF export
    }
}

struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App icon and info
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)

                        Text("BetterUntis")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("An alternative mobile client for the Untis timetable system")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.headline)

                        FeatureRow(icon: "calendar", title: "Modern Timetable View", description: "Clean and intuitive weekly timetable display")
                        FeatureRow(icon: "info.circle", title: "Info Center", description: "Messages, homework, and exam information")
                        FeatureRow(icon: "location", title: "RoomFinder", description: "Find available rooms quickly")
                        FeatureRow(icon: "person.2", title: "Multi-Account", description: "Support for multiple Untis accounts")
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss handled by sheet
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(UserRepository())
}