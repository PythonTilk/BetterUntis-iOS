import Foundation

struct BaseResponse<T: Codable>: Codable {
    let jsonrpc: String
    let result: T?
    let error: UntisError?
    let id: String
}

struct UntisError: Codable, Error {
    let code: Int
    let message: String
    let data: String?
}