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
        let graphQL = GraphQL.Reputation(
            categories: ["1","2","3","4","5"].map(GraphQL.Reputation.Category.init(id:)),
            scope: .domain,
            status: .success,
            confidence: 5,
            ttl: 1,
            isMalicious: true
        )
        
        let testInstance = RealtimeReputation(graphQL: graphQL)
        XCTAssertEqual(testInstance.categories, [1,2,3,4,5])
        XCTAssertEqual(testInstance.scope, .domain)
        XCTAssertEqual(testInstance.status, .success)
        XCTAssertEqual(testInstance.confidence!, 5.0, accuracy: 0.001)
        XCTAssertEqual(testInstance.isMalicious, .malicious)
    }
    
    func test_scope_init() {
        XCTAssertEqual(RealtimeReputation.Scope(graphQL: GraphQL.Scope.domain), .domain)
        XCTAssertEqual(RealtimeReputation.Scope(graphQL: GraphQL.Scope.path), .path)
        XCTAssertNil(RealtimeReputation.Scope(graphQL: GraphQL.Scope.unknown("")))
    }
    
    func test_status_init() {
        XCTAssertEqual(RealtimeReputation.Status(graphQL: GraphQL.ReputationStatus.notFound), .notFound)
        XCTAssertEqual(RealtimeReputation.Status(graphQL: GraphQL.ReputationStatus.success), .success)
        XCTAssertEqual(RealtimeReputation.Status(graphQL: GraphQL.ReputationStatus.unknown("")), .notFound)
    }
    
    func test_maliciousState_init() {
        XCTAssertEqual(RealtimeReputation.MaliciousState(graphQL: true), .malicious)
        XCTAssertEqual(RealtimeReputation.MaliciousState(graphQL: false), .notMalicious)
        XCTAssertEqual(RealtimeReputation.MaliciousState(graphQL: nil), .unknown)
    }
}
