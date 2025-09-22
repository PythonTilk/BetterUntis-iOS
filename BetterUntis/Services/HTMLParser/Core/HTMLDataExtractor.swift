import Foundation
import SwiftSoup

/// Extracts structured data from WebUntis HTML pages
class HTMLDataExtractor {

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()

    /// Extract absence data from HTML
    func extractAbsences(from html: String) throws -> [HTMLParsedAbsence] {
        print("🔍 Extracting absence data from HTML...")
        let doc = try SwiftSoup.parse(html)

        var absences: [HTMLParsedAbsence] = []

        // Try different selectors for absence data
        let absenceSelectors = [
            "table.list tr:not(.header)",
            ".absence-row",
            ".datarow",
            "tbody tr",
            ".list-item"
        ]

        for selector in absenceSelectors {
            do {
                let rows = try doc.select(selector)
                if !rows.isEmpty() {
                    print("✅ Found absence rows with selector: \(selector)")
                    absences = try parseAbsenceRows(rows)
                    break
                }
            } catch {
                continue
            }
        }

        // Fallback: search for text patterns
        if absences.isEmpty {
            absences = try parseAbsenceText(html)
        }

        print("📊 Extracted \(absences.count) absences")
        return absences
    }

    /// Extract exam data from HTML
    func extractExams(from html: String) throws -> [HTMLParsedExam] {
        print("🔍 Extracting exam data from HTML...")
        let doc = try SwiftSoup.parse(html)

        var exams: [HTMLParsedExam] = []

        // Look for exam indicators
        let examSelectors = [
            ".exam-row",
            ".klausur",
            "tr[class*='exam']",
            ".yellow",
            "[style*='yellow']",
            ".highlight"
        ]

        for selector in examSelectors {
            do {
                let rows = try doc.select(selector)
                if !rows.isEmpty() {
                    print("✅ Found exam rows with selector: \(selector)")
                    exams = try parseExamRows(rows)
                    break
                }
            } catch {
                continue
            }
        }

        // Search for exam text patterns
        if exams.isEmpty {
            exams = try parseExamText(html)
        }

        print("📊 Extracted \(exams.count) exams")
        return exams
    }

    /// Extract homework data from HTML
    func extractHomework(from html: String) throws -> [HTMLParsedHomework] {
        print("🔍 Extracting homework data from HTML...")
        let doc = try SwiftSoup.parse(html)

        var homework: [HTMLParsedHomework] = []

        let homeworkSelectors = [
            ".homework-row",
            ".hausaufgabe",
            "tr[class*='homework']",
            ".assignment"
        ]

        for selector in homeworkSelectors {
            do {
                let rows = try doc.select(selector)
                if !rows.isEmpty() {
                    print("✅ Found homework rows with selector: \(selector)")
                    homework = try parseHomeworkRows(rows)
                    break
                }
            } catch {
                continue
            }
        }

        if homework.isEmpty {
            homework = try parseHomeworkText(html)
        }

        print("📊 Extracted \(homework.count) homework items")
        return homework
    }

    /// Extract timetable with status information
    func extractTimetableWithStatus(from html: String) throws -> [HTMLParsedPeriod] {
        print("🔍 Extracting enhanced timetable data from HTML...")
        let doc = try SwiftSoup.parse(html)

        var periods: [HTMLParsedPeriod] = []

        let timetableSelectors = [
            ".timetable-period",
            ".period",
            ".lesson",
            "td[class*='period']",
            "tr.datarow td"
        ]

        for selector in timetableSelectors {
            do {
                let elements = try doc.select(selector)
                if !elements.isEmpty() {
                    print("✅ Found timetable periods with selector: \(selector)")
                    periods = try parseTimetablePeriods(elements)
                    break
                }
            } catch {
                continue
            }
        }

        print("📊 Extracted \(periods.count) enhanced periods")
        return periods
    }

    // MARK: - Private Parsing Methods

    private func parseAbsenceRows(_ rows: Elements) throws -> [HTMLParsedAbsence] {
        var absences: [HTMLParsedAbsence] = []

        for row in rows {
            do {
                let cells = try row.select("td")
                guard cells.count >= 3 else { continue }

                // Extract basic absence info
                let dateText = try cells[0].text().trimmingCharacters(in: .whitespacesAndNewlines)
                let reasonText = try cells[1].text().trimmingCharacters(in: .whitespacesAndNewlines)
                let statusText = try cells[2].text().trimmingCharacters(in: .whitespacesAndNewlines)

                // Parse date
                guard let date = parseDate(from: dateText) else { continue }

                let absence = HTMLParsedAbsence(
                    id: UUID().uuidString,
                    startDate: date,
                    endDate: date,
                    reason: reasonText.isEmpty ? nil : reasonText,
                    isExcused: statusText.lowercased().contains("entschuldigt") || statusText.lowercased().contains("excused"),
                    isApproved: statusText.lowercased().contains("genehmigt") || statusText.lowercased().contains("approved")
                )

                absences.append(absence)
            } catch {
                continue
            }
        }

        return absences
    }

    private func parseAbsenceText(_ html: String) throws -> [HTMLParsedAbsence] {
        var absences: [HTMLParsedAbsence] = []

        // Search for absence patterns in text
        let absencePatterns = [
            "abwesen",
            "fehlzeit",
            "krank",
            "absent",
            "entschuldigt",
            "unentschuldigt"
        ]

        for pattern in absencePatterns {
            if html.lowercased().contains(pattern) {
                // Create a generic absence entry
                let absence = HTMLParsedAbsence(
                    id: UUID().uuidString,
                    startDate: Date(),
                    endDate: Date(),
                    reason: "Found absence indicator: \(pattern)"
                )
                absences.append(absence)
                break
            }
        }

        return absences
    }

    private func parseExamRows(_ rows: Elements) throws -> [HTMLParsedExam] {
        var exams: [HTMLParsedExam] = []

        for row in rows {
            do {
                let cells = try row.select("td")
                guard cells.count >= 2 else { continue }

                let dateText = try cells[0].text().trimmingCharacters(in: .whitespacesAndNewlines)
                let subjectText = try cells[1].text().trimmingCharacters(in: .whitespacesAndNewlines)

                guard let date = parseDate(from: dateText) else { continue }

                let exam = HTMLParsedExam(
                    id: UUID().uuidString,
                    date: date,
                    startTime: "08:00",
                    endTime: "09:30",
                    subject: subjectText,
                    examType: "exam"
                )

                exams.append(exam)
            } catch {
                continue
            }
        }

        return exams
    }

    private func parseExamText(_ html: String) throws -> [HTMLParsedExam] {
        var exams: [HTMLParsedExam] = []

        let examPatterns = [
            "klausur",
            "prüfung",
            "exam",
            "test"
        ]

        for pattern in examPatterns {
            if html.lowercased().contains(pattern) {
                let exam = HTMLParsedExam(
                    id: UUID().uuidString,
                    date: Date(),
                    startTime: "08:00",
                    endTime: "09:30",
                    subject: "Exam found: \(pattern)",
                    examType: pattern
                )
                exams.append(exam)
                break
            }
        }

        return exams
    }

    private func parseHomeworkRows(_ rows: Elements) throws -> [HTMLParsedHomework] {
        var homework: [HTMLParsedHomework] = []

        for row in rows {
            do {
                let cells = try row.select("td")
                guard cells.count >= 3 else { continue }

                let subjectText = try cells[0].text().trimmingCharacters(in: .whitespacesAndNewlines)
                let titleText = try cells[1].text().trimmingCharacters(in: .whitespacesAndNewlines)
                let dueDateText = try cells[2].text().trimmingCharacters(in: .whitespacesAndNewlines)

                guard let dueDate = parseDate(from: dueDateText) else { continue }

                let hw = HTMLParsedHomework(
                    id: UUID().uuidString,
                    subject: subjectText,
                    assignedDate: Date(),
                    dueDate: dueDate,
                    title: titleText,
                    description: titleText
                )

                homework.append(hw)
            } catch {
                continue
            }
        }

        return homework
    }

    private func parseHomeworkText(_ html: String) throws -> [HTMLParsedHomework] {
        var homework: [HTMLParsedHomework] = []

        let homeworkPatterns = [
            "hausaufgabe",
            "aufgabe",
            "homework",
            "assignment"
        ]

        for pattern in homeworkPatterns {
            if html.lowercased().contains(pattern) {
                let hw = HTMLParsedHomework(
                    id: UUID().uuidString,
                    subject: "Unknown",
                    assignedDate: Date(),
                    dueDate: Date(),
                    title: "Homework found: \(pattern)",
                    description: "Found homework indicator: \(pattern)"
                )
                homework.append(hw)
                break
            }
        }

        return homework
    }

    private func parseTimetablePeriods(_ elements: Elements) throws -> [HTMLParsedPeriod] {
        var periods: [HTMLParsedPeriod] = []

        for element in elements {
            do {
                let text = try element.text()

                // Look for time patterns
                let timePattern = "\\d{1,2}[:.]\\d{2}"
                let regex = try NSRegularExpression(pattern: timePattern)
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

                if matches.count >= 2 {
                    let startTime = String(text[Range(matches[0].range, in: text)!])
                    let endTime = String(text[Range(matches[1].range, in: text)!])

                    // Check for status indicators
                    let isAbsent = text.lowercased().contains("abwesen") || text.lowercased().contains("absent")
                    let isCancelled = text.lowercased().contains("entfällt") || text.lowercased().contains("cancelled")
                    let hasExam = text.lowercased().contains("klausur") || text.lowercased().contains("exam")

                    let status: HTMLPeriodStatus
                    if isAbsent { status = .absent }
                    else if isCancelled { status = .cancelled }
                    else if hasExam { status = .exam }
                    else { status = .normal }

                    let period = HTMLParsedPeriod(
                        id: UUID().uuidString,
                        date: Date(),
                        startTime: startTime,
                        endTime: endTime,
                        subject: extractSubjectFromText(text),
                        status: status,
                        isAbsent: isAbsent,
                        isCancelled: isCancelled,
                        hasExam: hasExam
                    )

                    periods.append(period)
                }
            } catch {
                continue
            }
        }

        return periods
    }

    private func parseDate(from text: String) -> Date? {
        let dateFormats = [
            "dd.MM.yyyy",
            "dd.MM.yy",
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "MM/dd/yyyy"
        ]

        for format in dateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: text) {
                return date
            }
        }

        return nil
    }

    private func extractSubjectFromText(_ text: String) -> String? {
        // Common subject abbreviations
        let subjectPatterns = [
            "\\b[A-Z]{1,4}\\b", // Short abbreviations like "M", "D", "E"
            "Mathematik", "Deutsch", "Englisch", "Physik", "Chemie", "Biologie"
        ]

        for pattern in subjectPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                return String(text[Range(match.range, in: text)!])
            }
        }

        return nil
    }
}
