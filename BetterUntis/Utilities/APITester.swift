import Foundation

class APITester {
    static let shared = APITester()
    private let apiClient = UntisAPIClient()

    
    private init() {}

    // Test school search endpoint
    func testSchoolSearch() async {
        print("🧪 Testing school search...")
        do {
            let schools = try await apiClient.searchSchools(query: "test")
            print("✅ School search successful, found \(schools.count) schools")
        } catch {
            print("❌ School search failed: \(error.localizedDescription)")
        }
    }

    // Test a known WebUntis server endpoint
    func testKnownServer() async {
        print("🧪 Testing known server...")

        // Test with a public WebUntis demo/test server if available
        let testServerURL = "https://demo.webuntis.com/WebUntis/jsonrpc.do?school=Demo_HTL"

        do {
            let sessionId = try await apiClient.authenticate(
                apiUrl: testServerURL,
                user: "demo",
                password: "demo"
            )
            print("✅ Authentication successful, sessionId: \(sessionId.prefix(10))...")
        } catch {
            print("❌ Authentication failed: \(error.localizedDescription)")
        }
    }

    // Test URL parser
    func testURLParser() {
        print("🧪 Testing URL parser...")

        // Test WebUntis URL
        let testURL = "https://example.webuntis.com/WebUntis/?school=testschool"
        if let parsed = WebUntisURLParser.parseWebUntisURL(testURL) {
            print("✅ URL parsing successful:")
            print("   Server: \(parsed.server)")
            print("   School: \(parsed.school)")
        } else {
            print("❌ URL parsing failed")
        }

        // Test QR code
        let testQR = "untis://setschool?url=https://example.webuntis.com&school=testschool&user=testuser&key=testkey"
        if let parsed = WebUntisURLParser.parseQRCode(testQR) {
            print("✅ QR parsing successful:")
            print("   Server: \(parsed.server)")
            print("   School: \(parsed.school)")
            print("   User: \(parsed.username ?? "nil")")
        } else {
            print("❌ QR parsing failed")
        }
    }

    // Run all tests
    func runAllTests() async {
        print("🚀 Starting API tests...")

        testURLParser()
        await testSchoolSearch()
        await testKnownServer()

        print("🏁 Tests completed")
    }
}
