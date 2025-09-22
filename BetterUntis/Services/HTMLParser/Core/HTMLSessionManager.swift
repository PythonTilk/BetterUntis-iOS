import Foundation
import SwiftSoup

/// Manages web session authentication and navigation for WebUntis
class HTMLSessionManager {

    private let serverURL: String
    private let school: String
    private var cookies: [HTTPCookie] = []
    private var sessionCookie: String?
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config)
    }()

    init(serverURL: String, school: String) {
        self.serverURL = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL
        self.school = school
    }

    /// Check if currently authenticated
    var isAuthenticated: Bool {
        return sessionCookie != nil && !cookies.isEmpty
    }

    /// Login to WebUntis web interface
    /// - Parameters:
    ///   - username: Student username
    ///   - password: User password
    /// - Returns: Success status
    func login(username: String, password: String) async throws -> Bool {
        print("🔐 Attempting HTML login to \(serverURL) for school \(school)")

        // Step 1: Get login page to extract CSRF tokens and form data
        let loginPageURL = "\(serverURL)/WebUntis/?school=\(school)"
        let loginPageHTML = try await fetchPage(url: loginPageURL)

        // Step 2: Parse login form
        let loginForm = try parseLoginForm(html: loginPageHTML)

        // Step 3: Submit login credentials
        let success = try await submitLogin(
            form: loginForm,
            username: username,
            password: password
        )

        if success {
            print("✅ HTML login successful")
        } else {
            print("❌ HTML login failed")
        }

        return success
    }

    /// Fetch absence page HTML
    func fetchAbsencePage() async throws -> String {
        guard isAuthenticated else {
            throw WebUntisHTMLParserError.sessionExpired
        }

        // Common URLs for absence pages in different WebUntis versions
        let absenceURLs = [
            "\(serverURL)/WebUntis/main.do?school=\(school)#/basic/absences",
            "\(serverURL)/WebUntis/index.do?school=\(school)&method=absence",
            "\(serverURL)/WebUntis/classbook.do?school=\(school)&method=showAbsences",
            "\(serverURL)/WebUntis/studentabsences.do?school=\(school)"
        ]

        // Try each URL until we find the absence page
        for absenceURL in absenceURLs {
            do {
                let html = try await fetchPage(url: absenceURL)
                if html.contains("abwesen") || html.contains("absence") || html.contains("Fehlzeit") {
                    print("✅ Found absence page at: \(absenceURL)")
                    return html
                }
            } catch {
                print("⚠️ Failed to fetch \(absenceURL): \(error)")
                continue
            }
        }

        throw WebUntisHTMLParserError.pageNotFound("absence page")
    }

    /// Fetch exam page HTML
    func fetchExamPage(startDate: Date, endDate: Date) async throws -> String {
        guard isAuthenticated else {
            throw WebUntisHTMLParserError.sessionExpired
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)

        let examURLs = [
            "\(serverURL)/WebUntis/main.do?school=\(school)#/basic/exams",
            "\(serverURL)/WebUntis/exams.do?school=\(school)&startDate=\(startStr)&endDate=\(endStr)",
            "\(serverURL)/WebUntis/timetable.do?school=\(school)&startDate=\(startStr)&endDate=\(endStr)"
        ]

        for examURL in examURLs {
            do {
                let html = try await fetchPage(url: examURL)
                if html.contains("exam") || html.contains("Klausur") || html.contains("Prüfung") {
                    print("✅ Found exam page at: \(examURL)")
                    return html
                }
            } catch {
                continue
            }
        }

        throw WebUntisHTMLParserError.pageNotFound("exam page")
    }

    /// Fetch homework page HTML
    func fetchHomeworkPage(startDate: Date, endDate: Date) async throws -> String {
        guard isAuthenticated else {
            throw WebUntisHTMLParserError.sessionExpired
        }

        let homeworkURLs = [
            "\(serverURL)/WebUntis/main.do?school=\(school)#/basic/homework",
            "\(serverURL)/WebUntis/homework.do?school=\(school)",
            "\(serverURL)/WebUntis/classbook.do?school=\(school)&method=showHomework"
        ]

        for homeworkURL in homeworkURLs {
            do {
                let html = try await fetchPage(url: homeworkURL)
                if html.contains("homework") || html.contains("Hausaufgabe") || html.contains("Aufgabe") {
                    print("✅ Found homework page at: \(homeworkURL)")
                    return html
                }
            } catch {
                continue
            }
        }

        throw WebUntisHTMLParserError.pageNotFound("homework page")
    }

    /// Fetch timetable page HTML
    func fetchTimetablePage(startDate: Date, endDate: Date) async throws -> String {
        guard isAuthenticated else {
            throw WebUntisHTMLParserError.sessionExpired
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)

        let timetableURL = "\(serverURL)/WebUntis/timetable.do?school=\(school)&startDate=\(startStr)&endDate=\(endStr)"
        return try await fetchPage(url: timetableURL)
    }

    /// Logout from web interface
    func logout() async throws {
        if isAuthenticated {
            let logoutURL = "\(serverURL)/WebUntis/logout.do?school=\(school)"
            _ = try await fetchPage(url: logoutURL)

            // Clear session data
            sessionCookie = nil
            cookies.removeAll()
            print("🔓 Logged out from HTML session")
        }
    }

    // MARK: - Private Methods

    private func fetchPage(url: String) async throws -> String {
        guard let url = URL(string: url) else {
            throw WebUntisHTMLParserError.networkError("Invalid URL: \(url)")
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("de-DE,de;q=0.8,en;q=0.6", forHTTPHeaderField: "Accept-Language")

        // Add cookies if available
        if !cookies.isEmpty {
            let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeader {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        let (data, response) = try await urlSession.data(for: request)

        // Store cookies
        if let httpResponse = response as? HTTPURLResponse,
           let headerFields = httpResponse.allHeaderFields as? [String: String] {
            let newCookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
            cookies.append(contentsOf: newCookies)

            // Extract session cookie
            for cookie in newCookies {
                if cookie.name.lowercased().contains("session") || cookie.name == "JSESSIONID" {
                    sessionCookie = cookie.value
                }
            }
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw WebUntisHTMLParserError.networkError("Could not decode HTML response")
        }

        return html
    }

    private func parseLoginForm(html: String) throws -> LoginForm {
        let doc = try SwiftSoup.parse(html)

        // Find login form
        guard let form = try doc.select("form").first(where: { form in
            let action = try? form.attr("action")
            return action?.contains("login") == true || action?.contains("j_security_check") == true
        }) else {
            throw WebUntisHTMLParserError.parsingError("Could not find login form")
        }

        let action = try form.attr("action")
        let method = try form.attr("method").isEmpty ? "POST" : form.attr("method")

        // Extract form fields
        var fields: [String: String] = [:]
        let inputs = try form.select("input")

        for input in inputs {
            let name = try input.attr("name")
            let value = try input.attr("value")
            if !name.isEmpty {
                fields[name] = value
            }
        }

        return LoginForm(action: action, method: method, fields: fields)
    }

    private func submitLogin(form: LoginForm, username: String, password: String) async throws -> Bool {
        let actionURL = form.action.starts(with: "http") ? form.action : "\(serverURL)/\(form.action)"

        guard let url = URL(string: actionURL) else {
            throw WebUntisHTMLParserError.networkError("Invalid login URL: \(actionURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = form.method
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Prepare form data
        var formData = form.fields

        // Common field names for username/password
        let usernameFields = ["j_username", "user", "username", "login", "benutzername"]
        let passwordFields = ["j_password", "password", "passwd", "pass", "passwort"]

        for field in usernameFields {
            if formData.keys.contains(field) {
                formData[field] = username
                break
            }
        }

        for field in passwordFields {
            if formData.keys.contains(field) {
                formData[field] = password
                break
            }
        }

        // If standard fields not found, use common fallbacks
        if !formData.values.contains(username) {
            formData["j_username"] = username
        }
        if !formData.values.contains(password) {
            formData["j_password"] = password
        }

        // Convert to URL encoded data
        let formString = formData.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")

        request.httpBody = formString.data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)

        // Check for successful login
        if let httpResponse = response as? HTTPURLResponse {
            // Store cookies from login response
            if let headerFields = httpResponse.allHeaderFields as? [String: String] {
                let newCookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                cookies.append(contentsOf: newCookies)

                for cookie in newCookies {
                    if cookie.name.lowercased().contains("session") || cookie.name == "JSESSIONID" {
                        sessionCookie = cookie.value
                    }
                }
            }

            // Check if login was successful
            if let responseHTML = String(data: data, encoding: .utf8) {
                let success = !responseHTML.contains("error") &&
                             !responseHTML.contains("fehler") &&
                             !responseHTML.contains("invalid") &&
                             (responseHTML.contains("timetable") || responseHTML.contains("stundenplan") || responseHTML.contains("main.do"))
                return success
            }
        }

        return false
    }
}

// MARK: - Helper Models

struct LoginForm {
    let action: String
    let method: String
    let fields: [String: String]
}