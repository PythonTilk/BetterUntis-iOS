import Foundation
import os.log

/// Comprehensive debugging and logging system for BetterUntis
/// Provides structured logging with different levels and categories
class DebugLogger {
    static let shared = DebugLogger()

    // MARK: - Log Categories

    private let networkLogger = Logger(subsystem: "com.betteruntis.ios", category: "Network")
    private let authLogger = Logger(subsystem: "com.betteruntis.ios", category: "Authentication")
    private let dataLogger = Logger(subsystem: "com.betteruntis.ios", category: "Data")
    private let uiLogger = Logger(subsystem: "com.betteruntis.ios", category: "UI")
    private let errorLogger = Logger(subsystem: "com.betteruntis.ios", category: "Error")
    private let performanceLogger = Logger(subsystem: "com.betteruntis.ios", category: "Performance")
    private let debugLogger = Logger(subsystem: "com.betteruntis.ios", category: "Debug")

    // MARK: - Configuration

    /// Enable/disable debug logging (automatically disabled in release builds)
    static var isDebugEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Enable verbose logging for detailed debugging
    static var isVerboseLoggingEnabled = true

    private init() {}

    // MARK: - Network Logging

    static func logNetworkRequest(url: String, method: String = "GET", headers: [String: String]? = nil) {
        guard isDebugEnabled else { return }

        shared.networkLogger.info("🌐 \(method) \(url)")

        if isVerboseLoggingEnabled, let headers = headers {
            for (key, value) in headers {
                shared.networkLogger.debug("   Header: \(key) = \(value)")
            }
        }
    }

    static func logNetworkResponse(url: String, statusCode: Int, responseSize: Int? = nil, duration: TimeInterval? = nil) {
        guard isDebugEnabled else { return }

        let statusEmoji = statusCode < 300 ? "✅" : statusCode < 400 ? "⚠️" : "❌"
        var message = "\(statusEmoji) \(statusCode) \(url)"

        if let duration = duration {
            message += " (\(String(format: "%.2f", duration))s)"
        }

        if let size = responseSize {
            message += " [\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .binary))]"
        }

        if statusCode < 300 {
            shared.networkLogger.info("\(message)")
        } else if statusCode < 400 {
            shared.networkLogger.notice("\(message)")
        } else {
            shared.networkLogger.error("\(message)")
        }
    }

    static func logNetworkError(url: String, error: Error) {
        guard isDebugEnabled else { return }

        shared.networkLogger.error("❌ Network Error: \(url) - \(error.localizedDescription)")

        if isVerboseLoggingEnabled {
            shared.networkLogger.debug("   Full error: \(String(describing: error))")
        }
    }

    // MARK: - Authentication Logging

    static func logAuthAttempt(method: String, server: String, user: String) {
        guard isDebugEnabled else { return }

        shared.authLogger.info("🔐 Auth attempt: \(method) for user '\(user)' on \(server)")
    }

    static func logAuthSuccess(method: String, user: String) {
        guard isDebugEnabled else { return }

        shared.authLogger.info("✅ Auth successful: \(method) for user '\(user)'")
    }

    static func logAuthFailure(method: String, user: String, error: Error) {
        guard isDebugEnabled else { return }

        shared.authLogger.error("❌ Auth failed: \(method) for user '\(user)' - \(error.localizedDescription)")

        if isVerboseLoggingEnabled {
            shared.authLogger.debug("   Full error: \(String(describing: error))")
        }
    }

    static func logTokenRefresh(success: Bool) {
        guard isDebugEnabled else { return }

        if success {
            shared.authLogger.info("🔄 Token refresh successful")
        } else {
            shared.authLogger.error("❌ Token refresh failed")
        }
    }

    // MARK: - Data Logging

    static func logDataLoad(type: String, count: Int, duration: TimeInterval? = nil) {
        guard isDebugEnabled else { return }

        var message = "📊 Loaded \(count) \(type)"
        if let duration = duration {
            message += " in \(String(format: "%.2f", duration))s"
        }

        shared.dataLogger.info("\(message)")
    }

    static func logDataSave(type: String, success: Bool) {
        guard isDebugEnabled else { return }

        if success {
            shared.dataLogger.info("💾 Saved \(type) successfully")
        } else {
            shared.dataLogger.error("❌ Failed to save \(type)")
        }
    }

    static func logDataCacheHit(type: String) {
        guard isDebugEnabled else { return }

        shared.dataLogger.debug("📋 Cache hit: \(type)")
    }

    static func logDataCacheMiss(type: String) {
        guard isDebugEnabled else { return }

        shared.dataLogger.debug("📋 Cache miss: \(type)")
    }

    // MARK: - UI Logging

    static func logViewLoad(viewName: String) {
        guard isDebugEnabled else { return }

        shared.uiLogger.info("📱 Loading view: \(viewName)")
    }

    static func logUserAction(action: String, context: String? = nil) {
        guard isDebugEnabled else { return }

        var message = "👆 User action: \(action)"
        if let context = context {
            message += " (\(context))"
        }

        shared.uiLogger.info("\(message)")
    }

    static func logNavigationEvent(from: String, to: String) {
        guard isDebugEnabled else { return }

        shared.uiLogger.info("🧭 Navigation: \(from) → \(to)")
    }

    // MARK: - Error Logging

    static func logError(_ error: Error, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        guard isDebugEnabled else { return }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        var message = "💥 Error in \(fileName):\(function):\(line)"

        if let context = context {
            message += " [\(context)]"
        }

        message += ": \(error.localizedDescription)"

        shared.errorLogger.error("\(message)")

        if isVerboseLoggingEnabled {
            shared.errorLogger.debug("   Full error: \(String(describing: error))")
        }
    }

    static func logCriticalError(_ error: Error, context: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let message = "🚨 CRITICAL ERROR in \(fileName):\(function):\(line) [\(context)]: \(error.localizedDescription)"

        shared.errorLogger.critical("\(message)")

        // Always log full error details for critical errors
        shared.errorLogger.error("   Full error: \(String(describing: error))")

        // In debug mode, also break into debugger
        #if DEBUG
        debugPrint("🚨 CRITICAL ERROR: \(message)")
        debugPrint("Full error: \(error)")
        #endif
    }

    // MARK: - Performance Logging

    static func logPerformanceMetric(operation: String, duration: TimeInterval, context: String? = nil) {
        guard isDebugEnabled else { return }

        let emoji = duration < 0.1 ? "⚡️" : duration < 1.0 ? "⏱️" : "🐌"
        var message = "\(emoji) \(operation): \(String(format: "%.3f", duration))s"

        if let context = context {
            message += " [\(context)]"
        }

        shared.performanceLogger.info("\(message)")
    }

    static func measurePerformance<T>(operation: String, context: String? = nil, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        logPerformanceMetric(operation: operation, duration: duration, context: context)
        return result
    }

    static func measureAsyncPerformance<T>(operation: String, context: String? = nil, block: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        logPerformanceMetric(operation: operation, duration: duration, context: context)
        return result
    }

    // MARK: - Debug Logging

    static func logDebug(_ message: String, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        guard isDebugEnabled else { return }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        var logMessage = "🔍 [\(fileName):\(function):\(line)]"

        if let context = context {
            logMessage += " [\(context)]"
        }

        logMessage += ": \(message)"

        shared.debugLogger.debug("\(logMessage)")
    }

    static func logInfo(_ message: String, context: String? = nil) {
        guard isDebugEnabled else { return }

        var logMessage = "ℹ️ \(message)"
        if let context = context {
            logMessage += " [\(context)]"
        }

        shared.debugLogger.info("\(logMessage)")
    }

    static func logWarning(_ message: String, context: String? = nil) {
        guard isDebugEnabled else { return }

        var logMessage = "⚠️ \(message)"
        if let context = context {
            logMessage += " [\(context)]"
        }

        shared.debugLogger.notice("\(logMessage)")
    }

    // MARK: - Memory Debugging

    static func logMemoryUsage(context: String? = nil) {
        guard isDebugEnabled else { return }

        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMemory = ByteCountFormatter.string(fromByteCount: Int64(memoryInfo.resident_size), countStyle: .memory)
            var message = "🧠 Memory usage: \(usedMemory)"

            if let context = context {
                message += " [\(context)]"
            }

            shared.performanceLogger.info("\(message)")
        }
    }

    // MARK: - State Debugging

    static func logStateChange(from: String, to: String, context: String? = nil) {
        guard isDebugEnabled else { return }

        var message = "🔄 State change: \(from) → \(to)"
        if let context = context {
            message += " [\(context)]"
        }

        shared.debugLogger.info("\(message)")
    }

    // MARK: - Crash Prevention

    static func logUnexpectedNil(variable: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let message = "⚠️ Unexpected nil value for '\(variable)' in \(fileName):\(function):\(line)"

        shared.errorLogger.error("\(message)")

        #if DEBUG
        debugPrint("⚠️ UNEXPECTED NIL: \(message)")
        #endif
    }

    static func logAssertion(_ condition: Bool, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard !condition else { return }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "🚨 Assertion failed in \(fileName):\(function):\(line): \(message)"

        shared.errorLogger.critical("\(logMessage)")

        #if DEBUG
        debugPrint("🚨 ASSERTION FAILED: \(logMessage)")
        assertionFailure(message)
        #endif
    }
}

// MARK: - Convenience Extensions

extension DebugLogger {
    /// Log API call with timing
    static func logAPICall<T>(_ call: String, block: () async throws -> T) async rethrows -> T {
        logNetworkRequest(url: call, method: "API")

        return try await measureAsyncPerformance(operation: "API Call: \(call)") {
            do {
                let result = try await block()
                logNetworkResponse(url: call, statusCode: 200)
                return result
            } catch {
                logNetworkError(url: call, error: error)
                throw error
            }
        }
    }

    /// Log view lifecycle events
    static func logViewLifecycle(_ event: String, view: String) {
        logDebug("\(event) for \(view)", context: "ViewLifecycle")
    }
}

// MARK: - Global Debug Functions

/// Quick debug print that only works in debug builds
func debugLog(_ message: String, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logDebug(message, context: context, file: file, function: function, line: line)
}

/// Quick error logging
func errorLog(_ error: Error, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    DebugLogger.logError(error, context: context, file: file, function: function, line: line)
}

/// Performance measurement wrapper
func measure<T>(_ operation: String, block: () throws -> T) rethrows -> T {
    return try DebugLogger.measurePerformance(operation: operation, block: block)
}

/// Async performance measurement wrapper
func measureAsync<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
    return try await DebugLogger.measureAsyncPerformance(operation: operation, block: block)
}