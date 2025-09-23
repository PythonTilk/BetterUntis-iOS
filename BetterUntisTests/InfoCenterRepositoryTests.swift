import XCTest
@testable import BetterUntis

@MainActor
final class InfoCenterRepositoryTests: XCTestCase {
    private var repository: InfoCenterRepository!

    override func setUp() {
        super.setUp()
        repository = InfoCenterRepository()
    }

    func testParseAbsenceRecordHandlesMixedFormats() throws {
        let payload: [[String: Any]] = [
            [
                "id": 77,
                "date": "2024-03-18",
                "startTime": "0805",
                "endTime": "0915",
                "reason": "Sick",
                "isExcused": true,
                "klasse": ["displayName": "1A"],
                "text": "Flu"
            ],
            [
                "absenceId": "78",
                "startDate": 20240317,
                "endDate": 20240318,
                "from": 1300,
                "to": 1500,
                "absenceReason": "Doctor",
                "class": "1A"
            ]
        ]
        let records = payload.compactMap(repository.parseAbsenceRecord)

        XCTAssertEqual(records.count, 2)

        let first = try XCTUnwrap(records.first)
        XCTAssertEqual(first.reason, "Sick")
        XCTAssertEqual(first.className, "1A")
        XCTAssertEqual(first.excused, true)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.hour, .minute], from: first.startDateTime)
        XCTAssertEqual(components.hour, 8)
        XCTAssertEqual(components.minute, 5)

        let second = try XCTUnwrap(records.last)
        XCTAssertEqual(second.reason, "Doctor")
        XCTAssertNil(second.excused)
    }

    func testParseHomeworkAttachmentCapturesMetadata() {
        let attachmentDict: [String: Any] = [
            "id": "7",
            "name": "Worksheet",
            "downloadUrl": "https://example.com/file.pdf",
            "fileSize": 2048,
            "mimeType": "application/pdf"
        ]

        guard let attachment = repository.parseHomeworkAttachment(from: attachmentDict) else {
            return XCTFail("Expected attachment to parse")
        }

        XCTAssertEqual(attachment.id, 7)
        XCTAssertEqual(attachment.name, "Worksheet")
        XCTAssertEqual(attachment.url, "https://example.com/file.pdf")
        XCTAssertEqual(attachment.fileSize, 2048)
        XCTAssertEqual(attachment.mimeType, "application/pdf")
    }

    func testFormattedTimeStringNormalizesLooseValues() {
        XCTAssertEqual(repository.formattedTimeString(from: "8:05"), "08:05")
        XCTAssertEqual(repository.formattedTimeString(from: 915), "09:15")
        XCTAssertNil(repository.formattedTimeString(from: "--"))
    }

    func testMessageParsingUsesAllFields() {
        let data: [[String: Any]] = [
            [
                "id": 101,
                "subject": "Parent Meeting",
                "text": "Meeting in room A1",
                "isExpired": false,
                "attachments": [["id": 1, "name": "Agenda.pdf", "url": "https://example.com/agenda.pdf"]]
            ],
            [
                "id": "102",
                "title": "School Trip",
                "message": "Departure at 7:30",
                "priority": "true",
                "files": []
            ]
        ]
        let messages = repository.parseMessages(data)
        XCTAssertEqual(messages.count, 2)
        let first = messages[0]
        XCTAssertEqual(first.subject, "Parent Meeting")
        XCTAssertEqual(first.attachments?.count, 1)
        XCTAssertEqual(first.attachments?.first?.name, "Agenda.pdf")
        let second = messages[1]
        XCTAssertEqual(second.subject, "School Trip")
        XCTAssertEqual(second.text, "Departure at 7:30")
        XCTAssertEqual(second.isImportant, true)
    }

    func testHomeworkParsingNormalizesDates() {
        let payload: [[String: Any]] = [
            [
                "id": 1,
                "lessonId": 33,
                "subjectId": 12,
                "teacherId": 4,
                "date": "2024-03-19",
                "dueDate": "2024-03-20",
                "text": "Worksheet",
                "remark": "Bring answers",
                "completed": false,
                "attachments": [["id": 5, "name": "Task.pdf", "url": "https://example.com/task.pdf"]]
            ]
        ]
        let items = repository.parseHomework(payload)
        XCTAssertEqual(items.count, 1)
        let homework = items[0]
        XCTAssertEqual(homework.text, "Worksheet")
        XCTAssertEqual(homework.attachments.count, 1)
        XCTAssertEqual(homework.attachments.first?.name, "Task.pdf")
    }

    func testExamParsingBuildsAssociatedEntities() {
        let payload: [[String: Any]] = [
            [
                "id": 44,
                "date": 20240405,
                "startTime": "0815",
                "endTime": "0945",
                "subject": ["displayName": "Mathematics"],
                "klassen": [["id": 1, "name": "1A"]],
                "teachers": [["id": 12, "name": "Smith"]],
                "rooms": [["id": 9, "name": "A1"]],
                "text": "Chapter 3",
                "examType": "Test",
                "name": "Math Test"
            ]
        ]
        let exams = repository.parseExams(payload)
        XCTAssertEqual(exams.count, 1)
        let exam = exams[0]
        XCTAssertEqual(exam.subject, "Mathematics")
        XCTAssertEqual(exam.classes.first?.name, "1A")
        XCTAssertEqual(exam.teachers.first?.name, "Smith")
        XCTAssertEqual(exam.rooms?.first?.name, "A1")
        XCTAssertEqual(exam.examType, "Test")
    }
}
