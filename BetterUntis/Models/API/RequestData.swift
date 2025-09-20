import Foundation

struct RequestData: Codable, @unchecked Sendable {
    let method: String
    let params: [AnyEncodable]
    let id: String
    let jsonrpc: String

    init(method: String, params: [AnyEncodable]) {
        self.method = method
        self.params = params
        self.id = UUID().uuidString
        self.jsonrpc = "2.0"
    }
}

struct AnyEncodable: Codable, @unchecked Sendable {
    private let encodable: Encodable

    init<T: Encodable>(_ encodable: T) {
        self.encodable = encodable
    }

    func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }

    init(from decoder: Decoder) throws {
        fatalError("AnyEncodable does not support decoding")
    }
}