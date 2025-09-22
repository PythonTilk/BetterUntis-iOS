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

func testMethod(_ method: String, params: [String: Any] = [:]) async {
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
            print("📡 \(method):")
            print("   \(responseString.prefix(200))...")
        }
        print()
    } catch {
        print("❌ \(method) failed: \(error)")
        print()
    }
}

Task {
    print("🔍 Testing absence and exam methods...")
    
    // First authenticate
    await testMethod("authenticate", params: [
        "user": username,
        "password": password,
        "client": "BetterUntis"
    ])
    
    // Test various absence methods
    let absenceMethods = [
        "getOwnAbsences",
        "getMyAbsences", 
        "getStudentAbsences",
        "getAbsences",
        "getPersonalAbsences",
        "getOwnTimetableForToday",
        "getCurrentUser",
        "getPersonId"
    ]
    
    for method in absenceMethods {
        await testMethod(method)
    }
    
    // Test with date parameters
    let today = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd"
    let todayString = formatter.string(from: today)
    
    let startDate = Calendar.current.date(byAdding: .month, value: -2, to: today)!
    let endDate = Calendar.current.date(byAdding: .month, value: 1, to: today)!
    let startDateStr = formatter.string(from: startDate)
    let endDateStr = formatter.string(from: endDate)
    
    await testMethod("getAbsences", params: [
        "startDate": startDateStr,
        "endDate": endDateStr
    ])
    
    await testMethod("getStudentAbsences", params: [
        "startDate": startDateStr,
        "endDate": endDateStr
    ])
    
    await testMethod("logout")
}

RunLoop.main.run()
