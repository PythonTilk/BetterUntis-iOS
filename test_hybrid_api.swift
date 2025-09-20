import Foundation

/// Comprehensive test suite for all API approaches: REST, JSONRPC, and HTML parsing
class HybridAPITester {

    // Test server configuration
    static let testServerURL = "https://mese.webuntis.com/WebUntis/?school=IT-Schule+Stuttgart"
    static let testUsername = "noel.burkhardt"
    static let testPassword = "Noel2008"
    static let testSchoolName = "IT-Schule Stuttgart"

    static func runComprehensiveTests() async {
        print("🚀 Starting Comprehensive API Tests")
        print("=====================================")

        // Phase 1: Test individual API clients
        await testRESTAPI()
        await testJSONRPCAPI()
        await testHTMLParsing() // Placeholder for now

        // Phase 2: Test hybrid service
        await testHybridService()

        // Phase 3: Performance and reliability tests
        await testPerformanceComparison()

        print("\n✅ All tests completed!")
    }

    // MARK: - REST API Tests

    static func testRESTAPI() async {
        print("\n🌐 Testing REST API Client")
        print("==========================")

        let baseURL = testServerURL.replacingOccurrences(of: "/WebUntis/?school=IT-Schule+Stuttgart", with: "")
        let restClient = UntisRESTClient(baseURL: baseURL, schoolName: testSchoolName)

        // Test connection
        print("🔍 Testing REST API connection...")
        let hasConnection = await restClient.testConnection()
        print("   Connection test: \(hasConnection ? "✅ Success" : "❌ Failed")")

        // Test authentication
        print("🔐 Testing REST API authentication...")
        do {
            let authResponse = try await restClient.authenticate(username: testUsername, password: testPassword)
            print("   ✅ Authentication successful")
            print("   Token type: \(authResponse.token_type)")
            print("   Expires in: \(authResponse.expires_in ?? 0) seconds")

            // Test user data retrieval
            print("👤 Testing user data retrieval...")
            do {
                let userData = try await restClient.getUserData()
                print("   ✅ User data retrieved: \(userData.keys.count) fields")
            } catch {
                print("   ⚠️ User data failed: \(error.localizedDescription)")
            }

            // Test timetable retrieval
            print("📅 Testing timetable retrieval...")
            do {
                let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

                let timetableResponse = try await restClient.getTimetable(
                    elementType: .student,
                    elementId: 1, // Test with ID 1
                    startDate: startDate,
                    endDate: endDate
                )

                print("   ✅ Timetable retrieved: \(timetableResponse.data.result.elements.count) periods")

                // Convert to periods for compatibility
                let periods = restClient.convertTimetableToPeriods(timetableResponse.data.result.elements)
                print("   📊 Converted periods: \(periods.count)")

            } catch {
                print("   ⚠️ Timetable failed: \(error.localizedDescription)")
            }

        } catch {
            print("   ❌ Authentication failed: \(error.localizedDescription)")
        }
    }

    // MARK: - JSONRPC API Tests

    static func testJSONRPCAPI() async {
        print("\n📡 Testing JSONRPC API Client")
        print("============================")

        let jsonrpcClient = UntisAPIClient()

        // Test connection
        print("🔍 Testing JSONRPC connection...")
        let hasConnection = await jsonrpcClient.testConnection(server: testServerURL, schoolName: testSchoolName)
        print("   Connection test: \(hasConnection ? "✅ Success" : "❌ Failed")")

        // Test authentication
        print("🔐 Testing JSONRPC authentication...")
        do {
            let userData = try await jsonrpcClient.authenticate(
                username: testUsername,
                password: testPassword,
                server: testServerURL,
                schoolName: testSchoolName
            )
            print("   ✅ Authentication successful")
            print("   User data: \(userData.keys.count) fields")

            // Test enhanced methods support
            print("🧪 Testing BetterUntis enhanced methods support...")
            let supportedMethods = await jsonrpcClient.testBetterUntisSupport()
            print("   Enhanced methods available:")
            for (method, supported) in supportedMethods {
                print("   - \(method): \(supported ? "✅" : "❌")")
            }

            // Test timetable retrieval
            print("📅 Testing timetable retrieval...")
            do {
                let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

                let periods = try await jsonrpcClient.getTimetable(
                    elementType: 5, // Student type
                    elementId: userData["personId"] as? Int ?? 1,
                    startDate: startDate,
                    endDate: endDate
                )

                print("   ✅ Timetable retrieved: \(periods.count) periods")

                // Print sample period data
                if let firstPeriod = periods.first {
                    print("   📊 Sample period: \(firstPeriod.subject ?? "N/A") at \(firstPeriod.startTime)")
                }

            } catch {
                print("   ⚠️ Timetable failed: \(error.localizedDescription)")
            }

            // Test enhanced absence methods
            print("🏥 Testing enhanced absence methods...")
            do {
                let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                let endDate = Date()

                let absences = try await jsonrpcClient.getStudentAbsencesEnhanced(
                    startDate: startDate,
                    endDate: endDate
                )

                print("   ✅ Absences retrieved: \(absences.count) entries")

            } catch {
                print("   ⚠️ Enhanced absences failed: \(error.localizedDescription)")
            }

            // Test enhanced homework methods
            print("📚 Testing enhanced homework methods...")
            do {
                let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                let endDate = Date()

                let homework = try await jsonrpcClient.getHomeworkEnhanced(
                    startDate: startDate,
                    endDate: endDate
                )

                print("   ✅ Homework retrieved: \(homework.count) entries")

            } catch {
                print("   ⚠️ Enhanced homework failed: \(error.localizedDescription)")
            }

            // Test enhanced exam methods
            print("📝 Testing enhanced exam methods...")
            do {
                let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

                let exams = try await jsonrpcClient.getExamsEnhanced(
                    startDate: startDate,
                    endDate: endDate
                )

                print("   ✅ Exams retrieved: \(exams.count) entries")

            } catch {
                print("   ⚠️ Enhanced exams failed: \(error.localizedDescription)")
            }

        } catch {
            print("   ❌ Authentication failed: \(error.localizedDescription)")
        }
    }

    // MARK: - HTML Parser Tests

    static func testHTMLParsing() async {
        print("\n🌐 Testing HTML Parser")
        print("======================")

        print("🔄 HTML parser integration pending...")
        print("   Will test:")
        print("   - Web authentication with session management")
        print("   - Absence data extraction from HTML tables")
        print("   - Exam data parsing from timetable")
        print("   - Homework assignment parsing")
        print("   - Timetable with enhanced status information")

        // TODO: Implement when HTML parser package is integrated
        // let htmlParser = WebUntisHTMLParser(serverURL: testServerURL, schoolName: testSchoolName)
        // ...
    }

    // MARK: - Hybrid Service Tests

    static func testHybridService() async {
        print("\n🔄 Testing Hybrid Service")
        print("==========================")

        let hybridService = HybridUntisService.create(for: testServerURL, schoolName: testSchoolName)

        // Test server capabilities detection
        print("🔍 Testing server capabilities detection...")
        await hybridService.testServerCapabilities(serverURL: testServerURL, schoolName: testSchoolName)

        let status = hybridService.getServiceStatus()
        print("   Server capabilities:")
        for (key, value) in status {
            print("   - \(key): \(value)")
        }

        // Test hybrid authentication
        print("🔐 Testing hybrid authentication...")
        do {
            try await hybridService.authenticate(
                username: testUsername,
                password: testPassword,
                serverURL: testServerURL,
                schoolName: testSchoolName
            )

            print("   ✅ Hybrid authentication successful")
            print("   Method used: \(hybridService.currentAuthMethod.rawValue)")

            // Test hybrid timetable retrieval
            print("📅 Testing hybrid timetable retrieval...")
            do {
                let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

                let periods = try await hybridService.getTimetable(
                    elementType: .student,
                    elementId: 1,
                    startDate: startDate,
                    endDate: endDate
                )

                print("   ✅ Hybrid timetable retrieved: \(periods.count) periods")

            } catch {
                print("   ⚠️ Hybrid timetable failed: \(error.localizedDescription)")
            }

            // Test hybrid absence retrieval
            print("🏥 Testing hybrid absence retrieval...")
            do {
                let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                let endDate = Date()

                let absences = try await hybridService.getStudentAbsences(
                    startDate: startDate,
                    endDate: endDate
                )

                print("   ✅ Hybrid absences retrieved: \(absences.count) entries")

            } catch {
                print("   ⚠️ Hybrid absences failed: \(error.localizedDescription)")
            }

        } catch {
            print("   ❌ Hybrid authentication failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Performance Tests

    static func testPerformanceComparison() async {
        print("\n⚡ Performance Comparison Tests")
        print("===============================")

        // Test response times for different methods
        print("🏁 Testing timetable retrieval performance...")

        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

        // REST API performance
        print("   Testing REST API performance...")
        let restStartTime = Date()
        do {
            let baseURL = testServerURL.replacingOccurrences(of: "/WebUntis/?school=IT-Schule+Stuttgart", with: "")
            let restClient = UntisRESTClient(baseURL: baseURL, schoolName: testSchoolName)

            let _ = try await restClient.authenticate(username: testUsername, password: testPassword)
            let _ = try await restClient.getTimetable(
                elementType: .student,
                elementId: 1,
                startDate: startDate,
                endDate: endDate
            )

            let restTime = Date().timeIntervalSince(restStartTime)
            print("   REST API time: \(String(format: "%.2f", restTime))s")

        } catch {
            print("   REST API failed: \(error.localizedDescription)")
        }

        // JSONRPC performance
        print("   Testing JSONRPC performance...")
        let jsonrpcStartTime = Date()
        do {
            let jsonrpcClient = UntisAPIClient()
            let userData = try await jsonrpcClient.authenticate(
                username: testUsername,
                password: testPassword,
                server: testServerURL,
                schoolName: testSchoolName
            )

            let _ = try await jsonrpcClient.getTimetable(
                elementType: 5,
                elementId: userData["personId"] as? Int ?? 1,
                startDate: startDate,
                endDate: endDate
            )

            let jsonrpcTime = Date().timeIntervalSince(jsonrpcStartTime)
            print("   JSONRPC time: \(String(format: "%.2f", jsonrpcTime))s")

        } catch {
            print("   JSONRPC failed: \(error.localizedDescription)")
        }

        // HTML parser performance (placeholder)
        print("   HTML Parser performance: TBD (pending integration)")
    }
}

// MARK: - Main Test Execution

@main
struct APITestRunner {
    static func main() async {
        await HybridAPITester.runComprehensiveTests()
    }
}