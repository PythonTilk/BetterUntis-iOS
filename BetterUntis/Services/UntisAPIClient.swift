import Foundation
import Alamofire

class UntisAPIClient: ObservableObject {
    // MARK: - Constants
    static let defaultSchoolSearchURL = "https://schoolsearch.webuntis.com/schoolquery2"

    // API Methods
    static let methodCreateImmediateAbsence = "createImmediateAbsence2017"
    static let methodDeleteAbsence = "deleteAbsence2017"
    static let methodGetAbsences = "getStudentAbsences2017"
    static let methodGetAppSharedSecret = "getAppSharedSecret"
    static let methodGetAuthToken = "getAuthToken"
    static let methodGetExams = "getExams2017"
    static let methodGetHomework = "getHomeWork2017"
    static let methodGetMessages = "getMessagesOfDay2017"
    static let methodGetOfficeHours = "getOfficeHours2017"
    static let methodGetPeriodData = "getPeriodData2017"
    static let methodGetTimetable = "getTimetable2017"
    static let methodGetUserData = "getUserData2017"
    static let methodSearchSchools = "searchSchool"
    static let methodSubmitAbsencesChecked = "submitAbsencesChecked2017"
    static let methodGetLessonTopic = "getLessonTopic2017"
    static let methodSubmitLessonTopic = "submitLessonTopic"

    // MARK: - Properties
    private let session: Session
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    // MARK: - Initialization
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        self.session = Session(configuration: configuration)

        // Configure JSON decoder with custom date strategies
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try different date formats
            if dateString.count == 8 { // yyyyMMdd
                if let date = DateFormatter.iso8601Date.date(from: dateString) {
                    return date
                }
            } else if dateString.count == 12 { // yyyyMMddHHmm
                if let date = DateFormatter.iso8601DateTime.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
        }

        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let dateString = DateFormatter.iso8601DateTime.string(from: date)
            try container.encode(dateString)
        }
    }

    // MARK: - Generic API Request Method
    private func request<T: Codable>(
        url: String,
        method: String,
        parameters: [AnyEncodable]
    ) async throws -> T {
        let requestData = RequestData(method: method, params: parameters)

        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                url,
                method: .post,
                parameters: requestData,
                encoder: JSONParameterEncoder(encoder: jsonEncoder)
            )
            .validate()
            .responseDecodable(of: BaseResponse<T>.self, decoder: jsonDecoder) { response in
                switch response.result {
                case .success(let baseResponse):
                    if let result = baseResponse.result {
                        continuation.resume(returning: result)
                    } else if let error = baseResponse.error {
                        continuation.resume(throwing: UntisAPIError.serverError(error))
                    } else {
                        continuation.resume(throwing: UntisAPIError.unknown)
                    }
                case .failure(let error):
                    continuation.resume(throwing: UntisAPIError.networkError(error))
                }
            }
        }
    }

    // MARK: - Authentication Methods
    func getAppSharedSecret(
        apiUrl: String,
        user: String,
        password: String,
        token: String? = nil
    ) async throws -> String {
        let params = AppSharedSecretParams(user: user, password: password, token: token)
        return try await request(
            url: apiUrl,
            method: Self.methodGetAppSharedSecret,
            parameters: [AnyEncodable(params)]
        )
    }

    func getAuthToken(apiUrl: String, user: String?, key: String?) async throws -> String {
        let params = AuthTokenParams(auth: Auth(user: user, key: key))
        let response: AuthTokenResult = try await request(
            url: apiUrl,
            method: Self.methodGetAuthToken,
            parameters: [AnyEncodable(params)]
        )
        return response.token
    }

    func getUserData(apiUrl: String, user: String?, key: String?) async throws -> UserDataResult {
        let params = UserDataParams(auth: Auth(user: user, key: key))
        return try await request(
            url: apiUrl,
            method: Self.methodGetUserData,
            parameters: [AnyEncodable(params)]
        )
    }

    // MARK: - Timetable Methods
    func getTimetable(
        apiUrl: String,
        id: Int64,
        type: ElementType,
        startDate: Date,
        endDate: Date,
        masterDataTimestamp: Int64,
        timetableTimestamp: Int64 = 0,
        timetableTimestamps: [Int64] = [],
        user: String?,
        key: String?
    ) async throws -> TimetableResult {
        let params = TimetableParams(
            id: id,
            type: type,
            startDate: startDate,
            endDate: endDate,
            masterDataTimestamp: masterDataTimestamp,
            timetableTimestamp: timetableTimestamp,
            timetableTimestamps: timetableTimestamps,
            auth: Auth(user: user, key: key)
        )

        return try await request(
            url: apiUrl,
            method: Self.methodGetTimetable,
            parameters: [AnyEncodable(params)]
        )
    }

    func getPeriodData(
        apiUrl: String,
        periodIds: Set<Int64>,
        user: String?,
        key: String?
    ) async throws -> PeriodDataResult {
        let params = PeriodDataParams(periodIds: periodIds, auth: Auth(user: user, key: key))
        return try await request(
            url: apiUrl,
            method: Self.methodGetPeriodData,
            parameters: [AnyEncodable(params)]
        )
    }

    // MARK: - School Search
    func searchSchools(search: String) async throws -> [SchoolInfo] {
        let params = SchoolSearchParams(search: search)
        let response: SchoolSearchResult = try await request(
            url: Self.defaultSchoolSearchURL,
            method: Self.methodSearchSchools,
            parameters: [AnyEncodable(params)]
        )
        return response.schools
    }

    // MARK: - Info Center Methods
    func getMessages(
        apiUrl: String,
        date: Date,
        user: String?,
        key: String?
    ) async throws -> [MessageOfDay] {
        let params = MessagesOfDayParams(date: date, auth: Auth(user: user, key: key))
        return try await request(
            url: apiUrl,
            method: Self.methodGetMessages,
            parameters: [AnyEncodable(params)]
        )
    }

    func getHomework(
        apiUrl: String,
        startDate: Date,
        endDate: Date,
        user: String?,
        key: String?
    ) async throws -> [HomeWork] {
        let params = HomeworkParams(startDate: startDate, endDate: endDate, auth: Auth(user: user, key: key))
        return try await request(
            url: apiUrl,
            method: Self.methodGetHomework,
            parameters: [AnyEncodable(params)]
        )
    }

    func getExams(
        apiUrl: String,
        startDate: Date,
        endDate: Date,
        user: String?,
        key: String?
    ) async throws -> [Exam] {
        let params = ExamsParams(startDate: startDate, endDate: endDate, auth: Auth(user: user, key: key))
        return try await request(
            url: apiUrl,
            method: Self.methodGetExams,
            parameters: [AnyEncodable(params)]
        )
    }
}

// MARK: - Supporting Types
struct AuthTokenResult: Codable {
    let token: String
}

struct SchoolSearchResult: Codable {
    let schools: [SchoolInfo]
}

struct PeriodDataResult: Codable {
    let periods: [Period]
}

struct MessageOfDay: Codable {
    let id: Int64
    let subject: String
    let text: String
    let isExpired: Bool
}

struct Exam: Codable, Identifiable {
    let id: Int64
    let classes: [PeriodElement]
    let teachers: [PeriodElement]
    let students: [PeriodElement]
    let subject: String
    let date: Date
    let startTime: String
    let endTime: String
    let name: String
    let text: String
}

// MARK: - Error Types
enum UntisAPIError: Error, LocalizedError {
    case serverError(UntisError)
    case networkError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .serverError(let untisError):
            return "Server error: \(untisError.message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}