import Foundation

class URLBuilder {
    enum APIEndpoint {
        case jsonrpc
        case jsonrpcIntern
        case both // Try jsonrpc first, fallback to jsonrpc_intern

        var path: String {
            switch self {
            case .jsonrpc:
                return "/jsonrpc.do"
            case .jsonrpcIntern:
                return "/jsonrpc_intern.do"
            case .both:
                return "/jsonrpc.do" // Primary endpoint
            }
        }

        var fallbackPath: String? {
            switch self {
            case .both:
                return "/jsonrpc_intern.do"
            default:
                return nil
            }
        }
    }

    enum URLError: Error, LocalizedError {
        case invalidHostFormat(String)
        case malformedURL(String)
        case missingSchool

        var errorDescription: String? {
            switch self {
            case .invalidHostFormat(let host):
                return "Invalid API host format: \(host)"
            case .malformedURL(let url):
                return "Malformed URL: \(url)"
            case .missingSchool:
                return "School name is required"
            }
        }
    }

    /// Builds a robust WebUntis JSON-RPC API URL with proper validation and fallback
    /// - Parameters:
    ///   - apiHost: The API host URL (can be with or without protocol/path)
    ///   - schoolName: The school name for the query parameter
    ///   - endpoint: The API endpoint type to use
    /// - Returns: A validated API URL string
    /// - Throws: URLError for invalid inputs
    static func buildApiUrl(
        apiHost: String,
        schoolName: String,
        endpoint: APIEndpoint = .jsonrpc
    ) throws -> String {
        guard !schoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw URLError.missingSchool
        }

        let cleanHost = apiHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanHost.isEmpty else {
            throw URLError.invalidHostFormat(apiHost)
        }

        // Normalize the host URL
        let normalizedHost = normalizeHost(cleanHost)

        // Create URL components
        guard var components = URLComponents(string: normalizedHost) else {
            throw URLError.malformedURL(normalizedHost)
        }

        // Ensure we have a scheme
        if components.scheme == nil {
            components.scheme = "https"
        }

        // Build the path
        var path = components.path

        // Add /WebUntis if not present
        if !path.contains("/WebUntis") {
            if !path.hasPrefix("/") {
                path = "/" + path
            }
            if !path.hasSuffix("/") && path != "/" {
                path += "/"
            }
            if path == "/" {
                path = "/WebUntis"
            } else {
                path += "WebUntis"
            }
        }

        // Add the endpoint
        path += endpoint.path
        components.path = path

        // Add school parameter
        var queryItems = components.queryItems ?? []

        // Remove existing school parameter if present
        queryItems.removeAll { $0.name == "school" }

        // Add the school parameter
        queryItems.append(URLQueryItem(name: "school", value: schoolName))
        components.queryItems = queryItems

        // Validate final URL
        guard let finalURL = components.url?.absoluteString else {
            throw URLError.malformedURL("Failed to construct final URL")
        }

        print("🔗 Built API URL: \(finalURL)")
        return finalURL
    }

    /// Builds API URLs with fallback support
    /// - Parameters:
    ///   - apiHost: The API host URL
    ///   - schoolName: The school name
    /// - Returns: Array of URLs to try (primary first, then fallbacks)
    static func buildApiUrlsWithFallback(
        apiHost: String,
        schoolName: String
    ) throws -> [String] {
        var urls: [String] = []

        // Primary endpoint (public jsonrpc.do)
        do {
            let primaryUrl = try buildApiUrl(
                apiHost: apiHost,
                schoolName: schoolName,
                endpoint: .jsonrpc
            )
            urls.append(primaryUrl)
        } catch {
            print("⚠️ Failed to build primary URL: \(error)")
        }

        // Fallback endpoint (internal jsonrpc_intern.do)
        do {
            let fallbackUrl = try buildApiUrl(
                apiHost: apiHost,
                schoolName: schoolName,
                endpoint: .jsonrpcIntern
            )
            urls.append(fallbackUrl)
        } catch {
            print("⚠️ Failed to build fallback URL: \(error)")
        }

        guard !urls.isEmpty else {
            throw URLError.invalidHostFormat("Could not build any valid URLs from: \(apiHost)")
        }

        return urls
    }

    /// Normalizes various host formats to a consistent URL format
    /// - Parameter host: Raw host string from user input
    /// - Returns: Normalized host URL
    private static func normalizeHost(_ host: String) -> String {
        var normalizedHost = host

        // Remove trailing slashes
        while normalizedHost.hasSuffix("/") {
            normalizedHost.removeLast()
        }

        // Handle various input formats
        if !normalizedHost.hasPrefix("http://") && !normalizedHost.hasPrefix("https://") {
            // Check if it looks like a domain or includes path
            if normalizedHost.contains("/") || normalizedHost.contains("webuntis") {
                normalizedHost = "https://" + normalizedHost
            } else {
                // Assume it's just a domain, add common WebUntis path
                normalizedHost = "https://" + normalizedHost
            }
        }

        return normalizedHost
    }

    /// Validates if a URL is properly formatted
    /// - Parameter urlString: The URL string to validate
    /// - Returns: True if URL is valid
    static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              !scheme.isEmpty,
              let host = url.host,
              !host.isEmpty else {
            return false
        }

        return true
    }

    /// Extracts school name from a WebUntis URL if present
    /// - Parameter urlString: The URL string to parse
    /// - Returns: School name if found in URL parameters
    static func extractSchoolFromURL(_ urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        return components.queryItems?.first(where: { $0.name == "school" })?.value
    }
}