import Foundation

struct WebUntisLoginData {
    let server: String
    let school: String
    let username: String?
    let key: String?
    let isQRCode: Bool
}

class WebUntisURLParser {

    // MARK: - URL Parsing

    /// Parse a WebUntis URL and extract login information
    /// Supports formats like: https://server.webuntis.com/WebUntis/?school=schoolname
    static func parseWebUntisURL(_ urlString: String) -> WebUntisLoginData? {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }

        // Extract server from host
        let server = host

        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        var school = ""

        for item in queryItems {
            if item.name == "school", let value = item.value {
                school = value
                break
            }
        }

        guard !school.isEmpty else {
            return nil
        }

        return WebUntisLoginData(
            server: server,
            school: school,
            username: nil,
            key: nil,
            isQRCode: false
        )
    }

    // MARK: - QR Code Parsing

    /// Parse a WebUntis QR code and extract login information
    /// Supports format: untis://setschool?url=...&school=...&user=...&key=...&schoolNumber=...
    static func parseQRCode(_ qrCodeString: String) -> WebUntisLoginData? {
        guard let url = URL(string: qrCodeString),
              url.scheme == "untis",
              url.host == "setschool" else {
            return nil
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        var serverURL = ""
        var school = ""
        var username = ""
        var key = ""

        for item in queryItems {
            guard let value = item.value else { continue }

            switch item.name {
            case "url":
                serverURL = value
            case "school":
                school = value
            case "user":
                username = value
            case "key":
                key = value
            default:
                break
            }
        }

        // Extract server from URL
        var server = ""
        if let serverURLObj = URL(string: serverURL), let host = serverURLObj.host {
            server = host
        } else {
            server = serverURL
        }

        guard !server.isEmpty, !school.isEmpty else {
            return nil
        }

        return WebUntisLoginData(
            server: server,
            school: school,
            username: username.isEmpty ? nil : username,
            key: key.isEmpty ? nil : key,
            isQRCode: true
        )
    }

    // MARK: - URL Building

    /// Build a proper API URL for WebUntis JSON-RPC calls
    /// Some servers use /jsonrpc.do, others use /jsonrpc_intern.do
    static func buildJsonRpcApiUrl(server: String, school: String) -> String {
        var baseURL = server

        // Ensure proper URL format
        if !baseURL.hasPrefix("https://") {
            baseURL = "https://" + baseURL
        }

        // Add /WebUntis if not present
        if !baseURL.contains("/WebUntis") {
            baseURL += "/WebUntis"
        }

        // Add JSON-RPC endpoint (try standard first)
        baseURL += "/jsonrpc.do"

        // Add school parameter
        var components = URLComponents(string: baseURL)!
        components.queryItems = [URLQueryItem(name: "school", value: school)]

        return components.url?.absoluteString ?? baseURL
    }

    /// Build alternative API URL using jsonrpc_intern.do endpoint
    static func buildAlternativeJsonRpcApiUrl(server: String, school: String) -> String {
        var baseURL = server

        // Ensure proper URL format
        if !baseURL.hasPrefix("https://") {
            baseURL = "https://" + baseURL
        }

        // Add /WebUntis if not present
        if !baseURL.contains("/WebUntis") {
            baseURL += "/WebUntis"
        }

        // Add alternative JSON-RPC endpoint
        baseURL += "/jsonrpc_intern.do"

        // Add school parameter
        var components = URLComponents(string: baseURL)!
        components.queryItems = [URLQueryItem(name: "school", value: school)]

        return components.url?.absoluteString ?? baseURL
    }

    // MARK: - Validation

    /// Check if a string looks like a WebUntis URL
    static func isWebUntisURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return false
        }

        return host.contains("webuntis.com") || url.absoluteString.contains("WebUntis")
    }

    /// Check if a string looks like a WebUntis QR code
    static func isWebUntisQRCode(_ qrString: String) -> Bool {
        return qrString.hasPrefix("untis://setschool")
    }
}