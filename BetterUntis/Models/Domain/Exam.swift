import Foundation

struct Exam: Codable, Identifiable, Sendable {
    let id: Int64
    let classes: [ExamClass]
    let teachers: [ExamTeacher]
    let students: [ExamStudent]
    let subject: String?
    let date: Date
    let startTime: String?
    let endTime: String?
    let rooms: [ExamRoom]?
    let text: String?
    let examType: String?
    let name: String?
}

struct ExamClass: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
}

struct ExamTeacher: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
}

struct ExamStudent: Codable, Identifiable, Sendable {
    let id: Int64
    let key: String
    let name: String
    let foreName: String
    let longName: String
}

struct ExamRoom: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let longName: String
}