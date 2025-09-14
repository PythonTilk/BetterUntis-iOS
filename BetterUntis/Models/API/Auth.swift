import Foundation

struct Auth: Codable {
    let user: String?
    let key: String?

    init(user: String?, key: String?) {
        self.user = user
        self.key = key
    }
}