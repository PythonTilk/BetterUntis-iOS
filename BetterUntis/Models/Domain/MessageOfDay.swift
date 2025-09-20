import Foundation

struct MessageOfDay: Codable, Identifiable, Sendable {
    let id: Int64
    let subject: String?
    let text: String?
    let isExpired: Bool?
    let isImportant: Bool?
    let attachments: [MessageAttachment]?
}

struct MessageAttachment: Codable, Identifiable, Sendable {
    let id: Int64
    let name: String
    let url: String?
}