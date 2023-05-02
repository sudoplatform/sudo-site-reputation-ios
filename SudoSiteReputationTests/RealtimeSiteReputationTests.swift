//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation
import Mockingbird

class RealtimeSiteReputationTests: XCTestCase {
    func test_realtimeReputation_init() {
        let graphQL = GraphQL.Reputation.init(reputationStatus: .notmalicious)
        let testInstance = SiteReputation(graphQL: graphQL)
        XCTAssertEqual(testInstance.status, .notMalicious)
    }
    
    func test_status_init() {
        XCTAssertEqual(SiteReputation.ReputationStatus(graphQL: GraphQL.ReputationStatus.malicious), .malicious)
        XCTAssertEqual(SiteReputation.ReputationStatus(graphQL: GraphQL.ReputationStatus.notmalicious), .notMalicious)
        XCTAssertEqual(SiteReputation.ReputationStatus(graphQL: GraphQL.ReputationStatus.unknown("")), .unkown)
    }
}
