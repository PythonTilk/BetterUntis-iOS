import Foundation

struct BaseResponse<T: Codable>: Codable, @unchecked Sendable {
    let jsonrpc: String
    let result: T?
    let error: UntisError?
    let id: String
}

struct UntisError: Codable, Error, @unchecked Sendable {
    let code: Int
    let message: String
    let data: String?
}