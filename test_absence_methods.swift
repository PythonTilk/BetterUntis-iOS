import Foundation

let server = "https://mese.webuntis.com/WebUntis/jsonrpc.do?school=IT-Schule+Stuttgart"
let username = "noel.burkhardt"
let password = "Noel2008"

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
