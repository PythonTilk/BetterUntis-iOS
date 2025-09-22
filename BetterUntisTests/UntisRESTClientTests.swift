import XCTest
@testable import BetterUntis

@MainActor
final class UntisRESTClientTests: XCTestCase {
    final class URLProtocolStub: URLProtocol {
        static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let handler = URLProtocolStub.requestHandler else {
                client?.urlProtocolDidFinishLoading(self)
                return
            }
            let (response, data) = handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    override func tearDown() {
        super.tearDown()
        URLProtocolStub.requestHandler = nil
    }

    func testNormalizeBaseURL() {
        XCTAssertEqual(
            UntisRESTClient.normalizeBaseURL("mese.webuntis.com/WebUntis/?token=true"),
            "https://mese.webuntis.com"
        )
        XCTAssertEqual(
            UntisRESTClient.normalizeBaseURL("https://demo.webuntis.com/WebUntis/index.do"),
            "https://demo.webuntis.com"
        )
    }

    func testTokenIdentifierSanitizesComponents() {
        let identifier = UntisRESTClient.makeTokenIdentifier(
            baseURL: "https://mese.webuntis.com",
            schoolName: "IT-Schule Stuttgart",
            userIdentifier: "Noel.Burkhardt"
        )
        XCTAssertEqual(identifier, "mese_webuntis_com_it-schule_stuttgart_noel_burkhardt")
    }

    func testCacheModeMapsToCacheControl() {
        XCTAssertEqual(RESTCacheMode.noCache.cacheControlValue, "no-store")
        XCTAssertEqual(RESTCacheMode.offlineOnly.cacheControlValue, "only-if-cached")
        XCTAssertEqual(RESTCacheMode.onlineOnly.cacheControlValue, "no-cache")
        XCTAssertEqual(RESTCacheMode.fullCache.cacheControlValue, "public, max-age=60")
    }

    func testTimetableEntriesUsesDateOnlyAndHeaders() async throws {
        let expectedData = Data("{\"format\":1,\"days\":[],\"errors\":[]}".utf8)
        let expectation = expectation(description: "Timetable request captured")
        var capturedRequest: URLRequest?

        URLProtocolStub.requestHandler = { request in
            DispatchQueue.main.async {
                capturedRequest = request
                expectation.fulfill()
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, expectedData)
        }

        let client = UntisRESTClient(
            baseURL: "https://unit.test",
            schoolName: "Test School",
            tokenIdentifier: "test-user",
            session: stubbedSession()
        )
        client.authToken = "access-token"

        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 8))!
        let endDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 14))!

        _ = try await client.getTimetableEntries(
            resourceType: .student,
            resourceIds: [19751],
            startDate: startDate,
            endDate: endDate,
            cacheMode: .noCache,
            layout: .priority
        )

        await fulfillment(of: [expectation], timeout: 1)

        guard let request = capturedRequest, let url = request.url else {
            return XCTFail("Expected request to be captured")
        }

        XCTAssertTrue(url.absoluteString.contains("start=2025-01-08"))
        XCTAssertTrue(url.absoluteString.contains("end=2025-01-14"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Mode"), "NO_CACHE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
    }

    func testRoomFinderAddsCacheHeadersAndQueryParameters() async throws {
        let expectedData = Data("""
        {
          "buildings": [],
          "departments": [],
          "roomTypes": [],
          "rooms": [
            {
              "id": 1,
              "displayName": "Room A1",
              "longName": "Room A1",
              "shortName": "A1",
              "availability": "NONE",
              "status": "REGULAR",
              "capacity": 0,
              "hasTimetable": false
            }
          ]
        }
        """.utf8)
        let expectation = expectation(description: "Room request captured")
        var capturedRequest: URLRequest?

        URLProtocolStub.requestHandler = { request in
            DispatchQueue.main.async {
                capturedRequest = request
                expectation.fulfill()
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, expectedData)
        }

        let client = UntisRESTClient(
            baseURL: "https://unit.test",
            schoolName: "Test School",
            tokenIdentifier: "test-user",
            session: stubbedSession()
        )
        client.authToken = "access-token"

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3600)

        _ = try await client.getAvailableRooms(startDateTime: start, endDateTime: end, cacheMode: .noCache)

        await fulfillment(of: [expectation], timeout: 1)

        guard let request = capturedRequest, let url = request.url else {
            return XCTFail("Expected request to be captured")
        }

        XCTAssertTrue(url.absoluteString.contains("startDateTime="))
        XCTAssertTrue(url.absoluteString.contains("endDateTime="))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Mode"), "NO_CACHE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
    }

    func testAbsenceRequestEncodesFullPayload() async throws {
        let expectedData = Data("{\"absences\":[]}".utf8)
        let expectation = expectation(description: "Absence request captured")
        var capturedRequest: URLRequest?
        var capturedBody: Data?

        URLProtocolStub.requestHandler = { request in
            DispatchQueue.main.async {
                capturedRequest = request
                capturedBody = self.bodyData(from: request)
                expectation.fulfill()
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, expectedData)
        }

        let client = UntisRESTClient(
            baseURL: "https://unit.test",
            schoolName: "Test School",
            tokenIdentifier: "test-user",
            session: stubbedSession()
        )
        client.authToken = "access-token"

        let payload = SaaDataRequest(
            classId: nil,
            dateRange: SaaDateRange(start: "2025-01-01T00:00:00", end: "2025-01-07T23:59:59"),
            dateRangeType: .week,
            studentId: 19751,
            studentGroupId: nil,
            excuseStatusType: .excused,
            filterForMissingLGNotifications: true
        )

        _ = try await client.getStudentAbsences(request: payload)

        await fulfillment(of: [expectation], timeout: 1)

        guard let request = capturedRequest, let body = capturedBody else {
            return XCTFail("Expected request and body")
        }

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")

        let decoded = try JSONDecoder().decode(SaaDataRequest.self, from: body)
        XCTAssertEqual(decoded.dateRange.start, "2025-01-01T00:00:00")
        XCTAssertEqual(decoded.dateRange.end, "2025-01-07T23:59:59")
        XCTAssertEqual(decoded.dateRangeType, .week)
        XCTAssertEqual(decoded.studentId, 19751)
        XCTAssertEqual(decoded.excuseStatusType, .excused)
        XCTAssertEqual(decoded.filterForMissingLGNotifications, true)
    }

    private func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
