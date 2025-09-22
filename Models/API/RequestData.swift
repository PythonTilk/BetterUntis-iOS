import Foundation

struct RequestData: Codable {
    let method: String
    let params: [AnyEncodable]
    let id: String = UUID().uuidString
    let jsonrpc: String = "2.0"
}

struct AnyEncodable: Codable {
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