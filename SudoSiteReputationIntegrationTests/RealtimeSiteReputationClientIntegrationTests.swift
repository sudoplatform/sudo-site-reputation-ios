//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SudoSiteReputation

class RealtimeSiteReputationClientIntegrationTests: IntegrationTestBase {

    var instance: DefaultSudoSiteReputationClient!
    
    override func setUp() async throws {
        try await super.setUp()
        self.instance = try DefaultSudoSiteReputationClient(userClient: self.userClient)
    }
    
    override func tearDown() async throws {
        try super.tearDownWithError()
    }
    
    func test_getReputation_returns_notMaliciousSite() async throws {
        let uri = "http://www.anonyome.com"
        let result = try await instance.getSiteReputation(url: uri)
        XCTAssertEqual(result.status, .notMalicious)
        XCTAssertEqual(result.categories, [])
    }

    func test_getReputation_returns_knownBadSite() async throws {
        let uri = "http://malware.wicar.org/data/eicar.com"
        let result = try await instance.getSiteReputation(url: uri)
        XCTAssertEqual(result.status, .malicious)
        XCTAssertEqual(result.categories.contains("MALWARE"), true)
        XCTAssertEqual(result.categories.contains("INFORMATION_COMPUTER_SECURITY"), true)
    }
}
