//
//  BetterUntisTests.swift
//  BetterUntisTests
//
//  Created by Noel Burkhardt on 17.09.25.
//

import Testing
@testable import BetterUntis

struct BetterUntisTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func authTokenMethodUsesCorrectRPCName() {
        #expect(UntisAPIClient.methodGetAuthToken == "getAuthToken")
    }

}
