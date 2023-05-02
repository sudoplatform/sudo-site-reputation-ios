//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation
import Mockingbird

class RealtimeSiteReputationClientTests: XCTestCase {

    var instanceUnderTest: DefaultSudoSiteReputationClient!
    var apiClient: APIClientMock!

    override func setUpWithError() throws {
        self.apiClient = mock(APIClient.self)
        self.instanceUnderTest = DefaultSudoSiteReputationClient(apiClient: apiClient)
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
                getSiteReputation: .init(reputationStatus: .notmalicious)
            )
        }
        let reputation = try
        await instanceUnderTest.getSiteReputation(url: testURL)
        XCTAssertEqual(reputation.status, .notMalicious)
    }
}

