import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif

@main
struct BetterUntisApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        setupDebugEnvironment()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    DebugLogger.logViewLoad(viewName: "ContentView")
                    ErrorTracker.trackCurrentView("ContentView")
                }
        }
    }

    private func setupDebugEnvironment() {
        // Initialize error tracking
        ErrorTracker.shared.loadErrorHistory()

        // Log app startup
        DebugLogger.logInfo("🚀 BetterUntis app starting up")
        DebugLogger.logInfo("Debug logging enabled: \(DebugLogger.isDebugEnabled)")
        DebugLogger.logInfo("Verbose logging enabled: \(DebugLogger.isVerboseLoggingEnabled)")

        // Log system information
        logSystemInformation()

        // Set up crash handling
        setupGlobalErrorHandling()

        DebugLogger.logInfo("✅ Debug environment setup complete")
    }

    private func logSystemInformation() {
        let device = UIDevice.current
        DebugLogger.logInfo("📱 Device: \(device.model) (\(device.systemName) \(device.systemVersion))")

        // Log memory information
        DebugLogger.logMemoryUsage(context: "App Startup")

        // Log build configuration
        #if DEBUG
        DebugLogger.logInfo("🔧 Build Configuration: DEBUG")
        #else
        DebugLogger.logInfo("🔧 Build Configuration: RELEASE")
        #endif

        // Log bundle information
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            DebugLogger.logInfo("📦 App Version: \(version) (Build \(build))")
        }
    }

    private func setupGlobalErrorHandling() {
        // Set up global error handling for SwiftUI
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {

                // Add global error boundary
                _ = window.rootViewController
                // This would be expanded with custom error handling if needed
            }
        }
    }
}
