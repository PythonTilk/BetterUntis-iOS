import Foundation
import SwiftSoup

/// Main HTML parser for WebUntis web interface
/// Provides fallback access to absence, exam, and homework data
/// when JSON-RPC API methods are not available
public class WebUntisHTMLParser {

    private let sessionManager: HTMLSessionManager
    private let dataExtractor: HTMLDataExtractor

    /// Initialize HTML parser with server configuration
    /// - Parameters:
    ///   - serverURL: Base URL of WebUntis server (e.g., "https://mese.webuntis.com")
    ///   - school: School identifier (e.g., "IT-Schule+Stuttgart")
    public init(serverURL: String, school: String) {
        self.sessionManager = HTMLSessionManager(serverURL: serverURL, school: school)
        self.dataExtractor = HTMLDataExtractor()
    }

    /// Authenticate with WebUntis web interface
    /// - Parameters:
    ///   - username: Student/user username
    ///   - password: User password
    /// - Returns: Success status
    public func authenticate(username: String, password: String) async throws -> Bool {
        return try await sessionManager.login(username: username, password: password)
    }

    /// Parse student absence data from web interface
    /// - Returns: Array of parsed absence records
    public func parseAbsences() async throws -> [HTMLParsedAbsence] {
        let html = try await sessionManager.fetchAbsencePage()
        return try dataExtractor.extractAbsences(from: html)
    }

    /// Parse exam data from timetable and exam pages
    /// - Parameters:
    ///   - startDate: Start date for exam search
    ///   - endDate: End date for exam search
    /// - Returns: Array of parsed exam records
    public func parseExams(startDate: Date, endDate: Date) async throws -> [HTMLParsedExam] {
        let html = try await sessionManager.fetchExamPage(startDate: startDate, endDate: endDate)
        return try dataExtractor.extractExams(from: html)
    }

    /// Parse homework assignments from web interface
    /// - Parameters:
    ///   - startDate: Start date for homework search
    ///   - endDate: End date for homework search
    /// - Returns: Array of parsed homework records
    public func parseHomework(startDate: Date, endDate: Date) async throws -> [HTMLParsedHomework] {
        let html = try await sessionManager.fetchHomeworkPage(startDate: startDate, endDate: endDate)
        return try dataExtractor.extractHomework(from: html)
    }

    /// Parse enhanced timetable with absence indicators
    /// - Parameters:
    ///   - startDate: Start date for timetable
    ///   - endDate: End date for timetable
    /// - Returns: Array of periods with absence/status information
    public func parseEnhancedTimetable(startDate: Date, endDate: Date) async throws -> [HTMLParsedPeriod] {
        let html = try await sessionManager.fetchTimetablePage(startDate: startDate, endDate: endDate)
        return try dataExtractor.extractTimetableWithStatus(from: html)
    }

    /// Logout from WebUntis web interface
    public func logout() async throws {
        try await sessionManager.logout()
    }

    /// Check if currently authenticated
    /// - Returns: Authentication status
    public var isAuthenticated: Bool {
        return sessionManager.isAuthenticated
    }
}

/// Errors that can occur during HTML parsing
public enum WebUntisHTMLParserError: Error, LocalizedError {
    case authenticationFailed(String)
    case networkError(String)
    case parsingError(String)
    case sessionExpired
    case pageNotFound(String)
    case unsupportedWebUntisVersion

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .sessionExpired:
            return "Session expired, please login again"
        case .pageNotFound(let page):
            return "Page not found: \(page)"
        case .unsupportedWebUntisVersion:
            return "Unsupported WebUntis version"
        }
    }
}
