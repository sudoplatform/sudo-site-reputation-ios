//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SudoSiteReputation

class RealtimeSiteReputationClientIntegrationTests: IntegrationTestBase {

    var instance: RealtimeSiteReputationClient!
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.instance = try RealtimeSiteReputationClient(userClient: self.userClient)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }

    func test_getReputation_returns_knownGoodSite() async throws {
        let uri = "http://www.google.com"
        let result = try await instance.getSiteReputation(url: uri)
        XCTAssertEqual(result.isMalicious, .notMalicious)
    }

    func test_getReputation_returns_knownBadSite() async throws {
        let uri = "http://malware.wicar.org/data/eicar.com"
        let result = try await instance.getSiteReputation(url: uri)
        XCTAssertEqual(result.isMalicious, .malicious)
    }
}
