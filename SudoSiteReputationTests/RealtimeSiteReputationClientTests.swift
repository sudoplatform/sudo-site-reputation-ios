//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation
import Mockingbird

class RealtimeSiteReputationClientTests: XCTestCase {

    var instanceUnderTest: RealtimeSiteReputationClient!
    var apiClient: APIClientMock!

    override func setUpWithError() throws {
        self.apiClient = mock(APIClient.self)
        self.instanceUnderTest = RealtimeSiteReputationClient(apiClient: apiClient)
    }

    func test_getSiteReputation_throwsError_when_apiClient_throws() async {
        let expectedError = TestError()
        do {
            let testURL = "foo.bar"
            givenSwift(await apiClient.getReputation(url: testURL)).will { _ in
                throw expectedError
            }
            _ = try await instanceUnderTest.getSiteReputation(url: testURL)
            XCTFail("expect error to be thrown")
        } catch {
            XCTAssertEqual(
                String(describing: error),
                String(describing: expectedError)
            )
        }
    }

    func test_getSiteReputation_success() async throws {
        let testURL = "foo.bar"
        givenSwift(await apiClient.getReputation(url: testURL)).will { _ in
            return GraphQL.GetSiteReputationQuery.Data(
                getSiteReputation: .init(categories: ["1","2","3","4","5"].map(GraphQL.GetSiteReputationQuery.Data.GetSiteReputation.Category.init(id:)),
                                         scope: .domain,
                                         status: .success,
                                         confidence: 9,
                                         ttl: 0,
                                         isMalicious: false)
            )
        }
        let reputation = try
        await instanceUnderTest.getSiteReputation(url: testURL)
        XCTAssertEqual(reputation.categories, [1,2,3,4,5])
        XCTAssertEqual(reputation.scope, .domain)
        XCTAssertEqual(reputation.status, .success)
        XCTAssertEqual(reputation.confidence!, 9.0, accuracy: 0.001)
        XCTAssertEqual(reputation.isMalicious, .notMalicious)
    }
}
