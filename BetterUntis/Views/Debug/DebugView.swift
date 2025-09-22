import SwiftUI
import MessageUI

/// Debug view for viewing error logs and system information during development
struct DebugView: View {
    @State private var selectedTab: DebugTab = .errors
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var showingMailComposer = false

    enum DebugTab: String, CaseIterable {
        case errors = "Errors"
        case logs = "Logs"
        case system = "System"
        case network = "Network"

        var icon: String {
            switch self {
            case .errors: return "exclamationmark.triangle"
            case .logs: return "doc.text"
            case .system: return "gear"
            case .network: return "network"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Debug tabs
                debugTabSelector

                // Content
                TabView(selection: $selectedTab) {
                    ErrorsView()
                        .tag(DebugTab.errors)

                    LogsView()
                        .tag(DebugTab.logs)

                    SystemInfoView()
                        .tag(DebugTab.system)

                    NetworkDebugView()
                        .tag(DebugTab.network)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Debug Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Export Error Report") {
                            exportErrorReport()
                        }

                        Button("Clear Error History") {
                            ErrorTracker.shared.clearErrorHistory()
                        }

                        Button("Trigger Test Error") {
                            triggerTestError()
                        }

                        #if DEBUG
                        Button("Toggle Verbose Logging") {
                            DebugLogger.isVerboseLoggingEnabled.toggle()
                        }
                        #endif

                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ActivityView(activityItems: [url])
            }
        }
        .sheet(isPresented: $showingMailComposer) {
            if MFMailComposeViewController.canSendMail() {
                MailComposer(errorReport: ErrorTracker.shared.generateErrorReport())
            } else {
                Text("Mail not configured")
            }
        }
    }

    private var debugTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(DebugTab.allCases, id: \.self) { tab in
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

    private func exportErrorReport() {
        if let url = ErrorTracker.shared.exportErrorReport() {
            exportURL = url
            showingExportSheet = true
        }
    }

    private func triggerTestError() {
        let testError = NSError(domain: "DebugTest", code: 999, userInfo: [NSLocalizedDescriptionKey: "This is a test error for debugging purposes"])
        trackError(testError, context: "User triggered test error")
    }
}

// MARK: - Errors View

struct ErrorsView: View {
    @State private var errors: [ErrorTracker.ErrorRecord] = []
    @State private var refreshTimer: Timer?

    var body: some View {
        List {
            if errors.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                    Text("No Errors")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("Great! No errors have been tracked.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(errors.reversed(), id: \.id) { error in
                    ErrorRowView(error: error)
                }
            }
        }
        .refreshable {
            refreshErrors()
        }
        .onAppear {
            refreshErrors()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    private func refreshErrors() {
        errors = ErrorTracker.shared.getErrorHistory()
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            refreshErrors()
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct ErrorRowView: View {
    let error: ErrorTracker.ErrorRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: error.context?.contains("CRITICAL") == true ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                    .foregroundColor(error.context?.contains("CRITICAL") == true ? .red : .orange)

                Text(error.error)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                Text(timeAgoSince(error.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let context = error.context {
                Text(context)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }

            Text("\(error.file):\(error.function):\(error.line)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text("Memory: \(ByteCountFormatter.string(fromByteCount: Int64(error.appState.memoryUsage), countStyle: .memory))")

                Spacer()

                if error.appState.isAuthenticated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Authenticated")
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Not Authenticated")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func timeAgoSince(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}

// MARK: - Logs View

struct LogsView: View {
    @State private var logEntries: [String] = []

    var body: some View {
        List {
            if logEntries.isEmpty {
                Text("No recent log entries")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(logEntries.indices, id: \.self) { index in
                    Text(logEntries[index])
                        .font(.system(.caption, design: .monospaced))
                        .padding(.vertical, 2)
                }
            }
        }
        .onAppear {
            loadRecentLogs()
        }
    }

    private func loadRecentLogs() {
        // This would integrate with the OS logging system to show recent logs
        // For now, show placeholder data
        logEntries = [
            "2025-01-15 14:30:15 [Info] App started",
            "2025-01-15 14:30:16 [Network] GET https://example.com/api",
            "2025-01-15 14:30:17 [Auth] Authentication successful",
            "2025-01-15 14:30:18 [UI] ContentView loaded"
        ]
    }
}

// MARK: - System Info View

struct SystemInfoView: View {
    @State private var systemInfo: [SystemInfoItem] = []

    struct SystemInfoItem {
        let title: String
        let value: String
        let icon: String
    }

    var body: some View {
        List {
            ForEach(systemInfo, id: \.title) { item in
                HStack {
                    Image(systemName: item.icon)
                        .foregroundColor(.blue)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(item.value)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            loadSystemInfo()
        }
    }

    private func loadSystemInfo() {
        let device = UIDevice.current

        // Get memory info
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let memoryUsage = kerr == KERN_SUCCESS ?
            ByteCountFormatter.string(fromByteCount: Int64(memoryInfo.resident_size), countStyle: .memory) : "Unknown"

        // Get disk space
        let diskSpace: String
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeBytes = systemAttributes[.systemFreeSize] as? UInt64 {
                diskSpace = ByteCountFormatter.string(fromByteCount: Int64(freeBytes), countStyle: .file)
            } else {
                diskSpace = "Unknown"
            }
        } catch {
            diskSpace = "Unknown"
        }

        systemInfo = [
            SystemInfoItem(title: "Device Model", value: device.model, icon: "iphone"),
            SystemInfoItem(title: "System Version", value: "\(device.systemName) \(device.systemVersion)", icon: "gear"),
            SystemInfoItem(title: "App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown", icon: "app.badge"),
            SystemInfoItem(title: "Build Number", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown", icon: "hammer"),
            SystemInfoItem(title: "Memory Usage", value: memoryUsage, icon: "memorychip"),
            SystemInfoItem(title: "Free Disk Space", value: diskSpace, icon: "internaldrive"),
            SystemInfoItem(title: "Debug Logging", value: DebugLogger.isDebugEnabled ? "Enabled" : "Disabled", icon: "ladybug"),
            SystemInfoItem(title: "Verbose Logging", value: DebugLogger.isVerboseLoggingEnabled ? "Enabled" : "Disabled", icon: "doc.text.magnifyingglass")
        ]
    }
}

// MARK: - Network Debug View

struct NetworkDebugView: View {
    var body: some View {
        List {
            Section("Network Status") {
                HStack {
                    Image(systemName: "wifi")
                        .foregroundColor(.green)
                    Text("Connected")
                    Spacer()
                    Text("Wi-Fi")
                        .foregroundColor(.secondary)
                }
            }

            Section("API Endpoints") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent requests will appear here")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MailComposer: UIViewControllerRepresentable {
    let errorReport: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.setSubject("BetterUntis Error Report")
        composer.setMessageBody(errorReport, isHTML: false)
        composer.mailComposeDelegate = context.coordinator
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

#if DEBUG
#Preview {
    DebugView()
}
#endif