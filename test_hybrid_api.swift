import Foundation

private func loadDotenv() {
    let fileManager = FileManager.default
    let envFileName = ".env"
    var searchURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)

    for _ in 0..<10 {
        let candidate = searchURL.appendingPathComponent(envFileName)
        if fileManager.fileExists(atPath: candidate.path) {
            if let contents = try? String(contentsOf: candidate, encoding: .utf8) {
                for line in contents.split(whereSeparator: { $0.isNewline }) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                    let parts = trimmed.split(separator: "=", maxSplits: 1).map { String($0) }
                    guard parts.count == 2 else { continue }
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    setenv(key, value, 1)
                }
            }
            break
        }

        let parent = searchURL.deletingLastPathComponent()
        if parent.path == searchURL.path { break }
        searchURL = parent
    }
}

private func requireEnv(_ key: String) -> String {
    if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
        return value
    }
    fatalError("Missing required environment variable '\(key)'. Create a .env file based on .env.example before running this script.")
}

private func encodedSchoolName(_ name: String) -> String {
    name.replacingOccurrences(of: " ", with: "+")
}

loadDotenv()

/// Comprehensive test suite for all API approaches: REST, JSONRPC, and HTML parsing
class HybridAPITester {

    // Test server configuration
    static let testBaseServer = requireEnv("UNTIS_BASE_SERVER").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    static let testSchoolName = requireEnv("UNTIS_SCHOOL")
    static let testServerURL = "\(testBaseServer)/WebUntis/?school=\(encodedSchoolName(testSchoolName))"
    static let testUsername = requireEnv("UNTIS_USERNAME")
    static let testPassword = requireEnv("UNTIS_PASSWORD")
    static let testStudentId: Int = {
        guard let value = Int(requireEnv("UNTIS_PERSON_ID")) else {
            fatalError("UNTIS_PERSON_ID must be a valid integer")
        }
        return value
    }()

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

        let restClient = UntisRESTClient.create(for: testBaseServer, schoolName: testSchoolName)

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
                    elementId: testStudentId,
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

        do {
            let parser = WebUntisHTMLParser(serverURL: testBaseServer, school: encodedSchoolName(testSchoolName))
            try await parser.authenticate(username: testUsername, password: testPassword)

            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

            let periods = try await parser.parseEnhancedTimetable(startDate: startDate, endDate: endDate)
            print("   ✅ HTML timetable periods: \(periods.count)")

            let absences = try await parser.parseAbsences()
            print("   ✅ HTML absences: \(absences.count)")

            let homework = try await parser.parseHomework(startDate: startDate, endDate: endDate)
            print("   ✅ HTML homework: \(homework.count)")

            let exams = try await parser.parseExams(startDate: startDate, endDate: endDate)
            print("   ✅ HTML exams: \(exams.count)")

            try await parser.logout()
        } catch {
            print("   ❌ HTML parser test failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Hybrid Service Tests

    static func testHybridService() async {
        print("\n🔄 Testing Hybrid Service")
        print("==========================")

        let hybridService = HybridUntisService.create(for: testBaseServer, schoolName: testSchoolName)

        // Test server capabilities detection
        print("🔍 Testing server capabilities detection...")
        await hybridService.testServerCapabilities(serverURL: testBaseServer, schoolName: testSchoolName)

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
                serverURL: testBaseServer,
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
                    elementId: testStudentId,
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
