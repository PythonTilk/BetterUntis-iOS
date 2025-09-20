import Foundation

struct Auth: Codable, Sendable {
    let user: String?
    let key: String?

    init(user: String?, key: String?) {
        self.user = user
        self.key = key
    }
}