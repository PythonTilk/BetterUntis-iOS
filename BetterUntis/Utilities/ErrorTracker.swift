import Foundation
import os.log
#if canImport(Darwin)
import Darwin
#endif

/// Error tracking and crash reporting system for debugging
class ErrorTracker {
    static let shared = ErrorTracker()

    private let logger = Logger(subsystem: "com.betteruntis.ios", category: "ErrorTracker")
    private var errorHistory: [ErrorRecord] = []
    private let maxErrorHistory = 100

    // MARK: - Error Record

    struct ErrorRecord: Codable {
        let id: UUID
        let timestamp: Date
        let error: String
        let context: String?
        let file: String
        let function: String
        let line: Int
        let stackTrace: [String]
        let appState: AppState

        init(error: String, context: String?, file: String, function: String, line: Int, stackTrace: [String], appState: AppState) {
            self.id = UUID()
            self.timestamp = Date()
            self.error = error
            self.context = context
            self.file = file
            self.function = function
            self.line = line
            self.stackTrace = stackTrace
            self.appState = appState
        }

        struct AppState: Codable {
            let isAuthenticated: Bool
            let currentView: String?
            let memoryUsage: UInt64
            let diskSpace: UInt64?
        }
    }

    private init() {
        setupCrashHandler()
    }

    // MARK: - Error Tracking

    func trackError(_ error: Error, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let stackTrace = Thread.callStackSymbols
        let appState = getCurrentAppState()

        let errorRecord = ErrorRecord(
            error: error.localizedDescription,
            context: context,
            file: URL(fileURLWithPath: file).lastPathComponent,
            function: function,
            line: line,
            stackTrace: stackTrace,
            appState: appState
        )

        addErrorRecord(errorRecord)

        // Log to system
        logger.error("Error tracked: \(error.localizedDescription) in \(errorRecord.file):\(function):\(line)")

        // In debug mode, also print to console
        #if DEBUG
        printErrorDetails(errorRecord)
        #endif
    }

    func trackCriticalError(_ error: Error, context: String, file: String = #file, function: String = #function, line: Int = #line) {
        trackError(error, context: "CRITICAL: \(context)", file: file, function: function, line: line)

        // Additional handling for critical errors
        logger.critical("CRITICAL ERROR: \(error.localizedDescription)")

        #if DEBUG
        // Break into debugger for critical errors
        raise(SIGINT)
        #endif
    }

    func trackAssertionFailure(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let assertionError = NSError(domain: "AssertionFailure", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        trackError(assertionError, context: "Assertion Failure", file: file, function: function, line: line)
    }

    // MARK: - Error History

    private func addErrorRecord(_ record: ErrorRecord) {
        errorHistory.append(record)

        // Maintain maximum history size
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeFirst(errorHistory.count - maxErrorHistory)
        }

        // Save to disk for persistence across app launches
        saveErrorHistory()
    }

    func getErrorHistory() -> [ErrorRecord] {
        return errorHistory
    }

    func getRecentErrors(count: Int = 10) -> [ErrorRecord] {
        return Array(errorHistory.suffix(count))
    }

    func clearErrorHistory() {
        errorHistory.removeAll()
        saveErrorHistory()
        logger.info("Error history cleared")
    }

    // MARK: - App State Tracking

    private func getCurrentAppState() -> ErrorRecord.AppState {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let memoryUsage: UInt64
        let kerr = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            memoryUsage = UInt64(memoryInfo.resident_size)
        } else {
            memoryUsage = 0
        }

        return ErrorRecord.AppState(
            isAuthenticated: false, // Will be updated when UserRepository is available
            currentView: getCurrentViewName(),
            memoryUsage: memoryUsage,
            diskSpace: getDiskSpace()
        )
    }

    private func getCurrentViewName() -> String? {
        // This would be updated by the view controllers/SwiftUI views
        return UserDefaults.standard.string(forKey: "currentView")
    }

    private func getDiskSpace() -> UInt64? {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            return systemAttributes[.systemFreeSize] as? UInt64
        } catch {
            return nil
        }
    }

    // MARK: - Crash Handling

    private func setupCrashHandler() {
        NSSetUncaughtExceptionHandler { exception in
            ErrorTracker.shared.handleUncaughtException(exception)
        }

        signal(SIGABRT) { _ in
            ErrorTracker.shared.handleSignal("SIGABRT")
        }

        signal(SIGILL) { _ in
            ErrorTracker.shared.handleSignal("SIGILL")
        }

        signal(SIGSEGV) { _ in
            ErrorTracker.shared.handleSignal("SIGSEGV")
        }

        signal(SIGFPE) { _ in
            ErrorTracker.shared.handleSignal("SIGFPE")
        }

        signal(SIGBUS) { _ in
            ErrorTracker.shared.handleSignal("SIGBUS")
        }
    }

    private func handleUncaughtException(_ exception: NSException) {
        let error = NSError(
            domain: "UncaughtException",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Uncaught exception: \(exception.name) - \(exception.reason ?? "Unknown reason")",
                "callStackSymbols": exception.callStackSymbols
            ]
        )

        trackCriticalError(error, context: "Uncaught Exception")

        logger.critical("Uncaught exception: \(exception.name as NSObject) - \(exception.reason ?? "Unknown")")

        // Save error history immediately
        saveErrorHistory()
    }

    private func handleSignal(_ signalName: String) {
        let error = NSError(
            domain: "Signal",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Signal received: \(signalName)"]
        )

        trackCriticalError(error, context: "Signal Handler")

        logger.critical("Signal received: \(signalName)")

        // Save error history immediately
        saveErrorHistory()
    }

    // MARK: - Persistence

    private var errorHistoryURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("error_history.json")
    }

    private func saveErrorHistory() {
        do {
            let data = try JSONEncoder().encode(errorHistory)
            try data.write(to: errorHistoryURL)
        } catch {
            logger.error("Failed to save error history: \(error.localizedDescription)")
        }
    }

    func loadErrorHistory() {
        do {
            let data = try Data(contentsOf: errorHistoryURL)
            errorHistory = try JSONDecoder().decode([ErrorRecord].self, from: data)
            logger.info("Loaded \(self.errorHistory.count) error records from disk")
        } catch {
            logger.info("No previous error history found or failed to load: \(error.localizedDescription)")
            errorHistory = []
        }
    }

    // MARK: - Debug Output

    private func printErrorDetails(_ record: ErrorRecord) {
        print("\n" + String(repeating: "=", count: 80))
        print("🚨 ERROR TRACKED")
        print(String(repeating: "=", count: 80))
        print("Time: \(record.timestamp)")
        print("Error: \(record.error)")
        if let context = record.context {
            print("Context: \(context)")
        }
        print("Location: \(record.file):\(record.function):\(record.line)")
        print("Memory Usage: \(ByteCountFormatter.string(fromByteCount: Int64(record.appState.memoryUsage), countStyle: .memory))")
        if let currentView = record.appState.currentView {
            print("Current View: \(currentView)")
        }
        print("Authenticated: \(record.appState.isAuthenticated)")

        if DebugLogger.isVerboseLoggingEnabled {
            print("\nStack Trace:")
            for (index, frame) in record.stackTrace.enumerated() {
                print("  \(index): \(frame)")
            }
        }
        print(String(repeating: "=", count: 80) + "\n")
    }

    // MARK: - Error Reporting

    func generateErrorReport() -> String {
        var report = "BetterUntis Error Report\n"
        report += "Generated: \(Date())\n"
        report += "Total Errors: \(errorHistory.count)\n\n"

        let recentErrors = getRecentErrors(count: 20)
        for (index, error) in recentErrors.enumerated() {
            report += "[\(index + 1)] \(error.timestamp): \(error.error)\n"
            if let context = error.context {
                report += "    Context: \(context)\n"
            }
            report += "    Location: \(error.file):\(error.function):\(error.line)\n\n"
        }

        return report
    }

    func exportErrorReport() -> URL? {
        let report = generateErrorReport()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("betteruntis_error_report.txt")

        do {
            try report.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            logger.error("Failed to export error report: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - View Tracking Extension

extension ErrorTracker {
    static func trackCurrentView(_ viewName: String) {
        UserDefaults.standard.set(viewName, forKey: "currentView")
    }
}

// MARK: - Convenience Functions

/// Track an error with context
func trackError(_ error: Error, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    ErrorTracker.shared.trackError(error, context: context, file: file, function: function, line: line)
}

/// Track a critical error
func trackCriticalError(_ error: Error, context: String, file: String = #file, function: String = #function, line: Int = #line) {
    ErrorTracker.shared.trackCriticalError(error, context: context, file: file, function: function, line: line)
}

/// Track assertion failure
func trackAssertion(_ condition: Bool, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    if !condition {
        ErrorTracker.shared.trackAssertionFailure(message, file: file, function: function, line: line)
    }
}
