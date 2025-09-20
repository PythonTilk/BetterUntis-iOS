import Foundation

// Test credentials from previous session
let server = "https://mese.webuntis.com/WebUntis/jsonrpc.do?school=IT-Schule+Stuttgart"
let username = "noel.burkhardt"
let password = "Noel2008"

struct APIClient {
    static func makeRequest(method: String, params: [String: Any] = [:]) async throws -> Any {
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

        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let error = json["error"] as? [String: Any] {
            throw NSError(domain: "API", code: (error["code"] as? Int) ?? -1, userInfo: [NSLocalizedDescriptionKey: error["message"] as? String ?? "Unknown error"])
        }

        return json["result"] ?? [:]
    }

    static func makeArrayRequest(method: String, params: [String: Any] = [:]) async throws -> [[String: Any]] {
        let result = try await makeRequest(method: method, params: params)
        if let array = result as? [[String: Any]] {
            return array
        }
        return []
    }
}

Task {
        print("🔄 Starting comprehensive API test...")
        print("📡 Server: \(server)")
        print("👤 User: \(username)")
        print()

        do {
            // 1. Authenticate
            print("1️⃣ Authenticating...")
            let authResult = try await APIClient.makeRequest(
                method: "authenticate",
                params: [
                    "user": username,
                    "password": password,
                    "client": "BetterUntis"
                ]
            )

            let sessionId = authResult["sessionId"] as? String ?? ""
            print("✅ Authentication successful - Session: \(sessionId.prefix(8))...")
            print()

            // 2. Get current timetable (today)
            let today = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            let todayString = formatter.string(from: today)

            print("2️⃣ Getting today's timetable (\(todayString))...")

            // Try multiple methods for timetable
            var timetableData: [[String: Any]] = []
            let timetableMethods = ["getTimetable2017", "getLessons", "getTimetableForToday", "getTimetableForElement"]

            for method in timetableMethods {
                do {
                    print("   Trying method: \(method)")
                    var params: [String: Any] = [:]

                    if method == "getTimetable2017" {
                        params = [
                            "id": 0,
                            "type": 5, // student
                            "startDate": todayString,
                            "endDate": todayString
                        ]
                    } else if method == "getLessons" {
                        // No params needed for getLessons
                    } else if method == "getTimetableForElement" {
                        params = [
                            "elementType": 5, // student
                            "elementId": 0,
                            "date": todayString
                        ]
                    }

                    timetableData = try await APIClient.makeArrayRequest(method: method, params: params)
                    print("✅ Found \(timetableData.count) periods using \(method)")
                    break
                } catch {
                    print("   ❌ \(method) failed: \(error)")
                }
            }

            // Analyze current lesson
            print()
            print("📚 CURRENT LESSON ANALYSIS:")
            let now = Date()
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HHmm"
            let currentTime = Int(timeFormatter.string(from: now)) ?? 0

            var currentLesson: [String: Any]?

            for period in timetableData {
                if let startTimeStr = period["startTime"] as? String,
                   let endTimeStr = period["endTime"] as? String,
                   let startTime = Int(startTimeStr),
                   let endTime = Int(endTimeStr) {

                    if currentTime >= startTime && currentTime <= endTime {
                        currentLesson = period
                        break
                    }
                }
            }

            if let lesson = currentLesson {
                print("📖 Currently in lesson:")
                if let subject = lesson["su"] as? [[String: Any]], !subject.isEmpty {
                    print("   Subject: \(subject[0]["name"] as? String ?? "Unknown")")
                }
                if let teacher = lesson["te"] as? [[String: Any]], !teacher.isEmpty {
                    print("   Teacher: \(teacher[0]["name"] as? String ?? "Unknown")")
                }
                if let room = lesson["ro"] as? [[String: Any]], !room.isEmpty {
                    print("   Room: \(room[0]["name"] as? String ?? "Unknown")")
                }
                print("   Time: \(lesson["startTime"] as? String ?? "")- \(lesson["endTime"] as? String ?? "")")
            } else {
                print("📭 No current lesson (not in session)")
            }

            // 3. Get room information
            print()
            print("3️⃣ Getting room information...")

            var roomData: [[String: Any]] = []
            let roomMethods = ["getRooms", "getRoomList", "getAllRooms"]

            for method in roomMethods {
                do {
                    print("   Trying method: \(method)")
                    roomData = try await APIClient.makeArrayRequest(method: method)
                    print("✅ Found \(roomData.count) rooms using \(method)")
                    break
                } catch {
                    print("   ❌ \(method) failed: \(error)")
                }
            }

            // Check who's in room 2.111
            print()
            print("🏠 ROOM 2.111 ANALYSIS:")

            // First find room 2.111 ID
            var room2111Id: Int?
            for room in roomData {
                if let name = room["name"] as? String, name.contains("2.111") {
                    room2111Id = room["id"] as? Int
                    print("🔍 Found room 2.111 with ID: \(room2111Id!)")
                    break
                }
            }

            if let roomId = room2111Id {
                // Check timetable for room usage
                var roomOccupancy: [[String: Any]] = []

                do {
                    roomOccupancy = try await APIClient.makeArrayRequest(
                        method: "getTimetable2017",
                        params: [
                            "id": roomId,
                            "type": 4, // room type
                            "startDate": todayString,
                            "endDate": todayString
                        ]
                    )
                } catch {
                    // Try alternative methods
                    for period in timetableData {
                        if let rooms = period["ro"] as? [[String: Any]] {
                            for room in rooms {
                                if room["id"] as? Int == roomId {
                                    roomOccupancy.append(period)
                                }
                            }
                        }
                    }
                }

                // Find current occupancy
                var currentOccupant: [String: Any]?
                for period in roomOccupancy {
                    if let startTimeStr = period["startTime"] as? String,
                       let endTimeStr = period["endTime"] as? String,
                       let startTime = Int(startTimeStr),
                       let endTime = Int(endTimeStr) {

                        if currentTime >= startTime && currentTime <= endTime {
                            currentOccupant = period
                            break
                        }
                    }
                }

                if let occupant = currentOccupant {
                    print("👥 Currently in room 2.111:")
                    if let classes = occupant["kl"] as? [[String: Any]], !classes.isEmpty {
                        print("   Class: \(classes[0]["name"] as? String ?? "Unknown")")
                    }
                    if let teacher = occupant["te"] as? [[String: Any]], !teacher.isEmpty {
                        print("   Teacher: \(teacher[0]["name"] as? String ?? "Unknown")")
                    }
                    if let subject = occupant["su"] as? [[String: Any]], !subject.isEmpty {
                        print("   Subject: \(subject[0]["name"] as? String ?? "Unknown")")
                    }
                } else {
                    print("🚫 Room 2.111 is currently empty")
                }
            } else {
                print("❌ Room 2.111 not found in room list")
            }

            // 4. Get student absences
            print()
            print("4️⃣ Getting student absences...")

            let startDate = Calendar.current.date(byAdding: .month, value: -1, to: today)!
            let endDate = Calendar.current.date(byAdding: .month, value: 1, to: today)!
            let startDateStr = formatter.string(from: startDate)
            let endDateStr = formatter.string(from: endDate)

            var absenceData: [[String: Any]] = []
            let absenceMethods = ["getStudentAbsences2017", "getStudentAbsences", "getAbsences"]

            for method in absenceMethods {
                do {
                    print("   Trying method: \(method)")
                    absenceData = try await APIClient.makeArrayRequest(
                        method: method,
                        params: [
                            "startDate": startDateStr,
                            "endDate": endDateStr
                        ]
                    )
                    print("✅ Found \(absenceData.count) absences using \(method)")
                    break
                } catch {
                    print("   ❌ \(method) failed: \(error)")
                }
            }

            print()
            print("🏥 STUDENT ABSENCES:")
            if absenceData.isEmpty {
                print("✅ No absences found")
            } else {
                for (index, absence) in absenceData.enumerated() {
                    print("   \(index + 1). \(absence)")
                }
            }

            // 5. Get upcoming exams
            print()
            print("5️⃣ Getting upcoming exams...")

            let futureDate = Calendar.current.date(byAdding: .month, value: 3, to: today)!
            let futureDateStr = formatter.string(from: futureDate)

            var examData: [[String: Any]] = []
            let examMethods = ["getExams2017", "getExaminations", "getTests"]

            for method in examMethods {
                do {
                    print("   Trying method: \(method)")
                    examData = try await APIClient.makeArrayRequest(
                        method: method,
                        params: [
                            "startDate": todayString,
                            "endDate": futureDateStr
                        ]
                    )
                    print("✅ Found \(examData.count) exams using \(method)")
                    break
                } catch {
                    print("   ❌ \(method) failed: \(error)")
                }
            }

            print()
            print("📝 UPCOMING EXAMS:")
            if examData.isEmpty {
                print("✅ No upcoming exams found")
            } else {
                // Sort exams by date
                let sortedExams = examData.sorted { exam1, exam2 in
                    let date1 = exam1["examDate"] as? String ?? ""
                    let date2 = exam2["examDate"] as? String ?? ""
                    return date1 < date2
                }

                for (index, exam) in sortedExams.enumerated() {
                    print("   \(index + 1). Date: \(exam["examDate"] as? String ?? "Unknown")")
                    print("       Subject: \(exam["subject"] as? String ?? "Unknown")")
                    print("       Type: \(exam["examType"] as? String ?? "Unknown")")
                    print()
                }

                if let nextExam = sortedExams.first {
                    print("🎯 NEXT EXAM:")
                    print("   Date: \(nextExam["examDate"] as? String ?? "Unknown")")
                    print("   Subject: \(nextExam["subject"] as? String ?? "Unknown")")
                }
            }

            // Logout
            print()
            print("6️⃣ Logging out...")
            let _ = try await APIClient.makeRequest(method: "logout")
            print("✅ Logged out successfully")

        } catch {
            print("❌ Error: \(error)")
        }
}