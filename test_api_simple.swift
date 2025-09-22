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

loadDotenv()

let server = requireEnv("UNTIS_SERVER_URL")
let username = requireEnv("UNTIS_USERNAME")
let password = requireEnv("UNTIS_PASSWORD")
func makeAPICall(method: String, params: [String: Any] = [:]) async {
    let url = URL(string: server)!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let requestData: [String: Any] = [
        "id": UUID().uuidString,
        "method": method,
        "params": params,
        "jsonrpc": "2.0"
    ]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
        let (data, _) = try await URLSession.shared.data(for: request)

        if let responseString = String(data: data, encoding: .utf8) {
            print("📡 \(method): \(responseString.prefix(500))...")
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let error = json["error"] as? [String: Any] {
            print("❌ \(method) failed: \(error["message"] as? String ?? "Unknown error")")
        } else if let result = json["result"] {
            print("✅ \(method) succeeded")
            if let dict = result as? [String: Any] {
                print("   Result keys: \(dict.keys.sorted())")
            } else if let array = result as? [Any] {
                print("   Result array count: \(array.count)")
            }
        }
    } catch {
        print("❌ \(method) error: \(error)")
    }
    print()
}

Task {
    print("🔄 Testing WebUntis API...")
    print("📡 Server: \(server)")
    print("👤 User: \(username)")
    print()

    // 1. Authenticate
    await makeAPICall(method: "authenticate", params: [
        "user": username,
        "password": password,
        "client": "BetterUntis"
    ])

    // 2. Try getting current date lessons
    let today = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd"
    let todayString = formatter.string(from: today)

    print("📅 Today: \(todayString)")

    // 3. Try various timetable methods
    await makeAPICall(method: "getLessons")
    await makeAPICall(method: "getTimetable2017", params: [
        "id": 0,
        "type": 5,
        "startDate": todayString,
        "endDate": todayString
    ])

    // 4. Try room methods
    await makeAPICall(method: "getRooms")
    await makeAPICall(method: "getRoomList")

    // 5. Try absence methods
    let startDate = Calendar.current.date(byAdding: .month, value: -1, to: today)!
    let endDate = Calendar.current.date(byAdding: .month, value: 1, to: today)!
    let startDateStr = formatter.string(from: startDate)
    let endDateStr = formatter.string(from: endDate)

    await makeAPICall(method: "getStudentAbsences2017", params: [
        "startDate": startDateStr,
        "endDate": endDateStr
    ])

    // 6. Try exam methods
    let futureDate = Calendar.current.date(byAdding: .month, value: 3, to: today)!
    let futureDateStr = formatter.string(from: futureDate)

    await makeAPICall(method: "getExams2017", params: [
        "startDate": todayString,
        "endDate": futureDateStr
    ])

    // 7. Logout
    await makeAPICall(method: "logout")

    print("🎯 Test completed!")
}

RunLoop.main.run()
