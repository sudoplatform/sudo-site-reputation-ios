//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation
import Mockingbird

class ReputationTests: XCTestCase {
    func test_Reputation_init() {
        let categories = ["MALWARE", "BALDING MEN THAT WORK OUT"]
        let graphQL = GraphQL.Reputation.init(reputationStatus: .notmalicious, categories: categories)
        let testInstance = SiteReputation(graphQL: graphQL)
        XCTAssertEqual(testInstance.status, .notMalicious)
        XCTAssertEqual(testInstance.categories, categories)
    }
    
    func test_status_init() {
        XCTAssertEqual(SiteReputation.ReputationStatus(graphQL: GraphQL.ReputationStatus.malicious), .malicious)
        XCTAssertEqual(SiteReputation.ReputationStatus(graphQL: GraphQL.ReputationStatus.notmalicious), .notMalicious)
        XCTAssertEqual(SiteReputation.ReputationStatus(graphQL: GraphQL.ReputationStatus.unknown("")), .unkown)
    }
}
