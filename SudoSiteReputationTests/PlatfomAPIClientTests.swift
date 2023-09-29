//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation
import SudoApiClient
@testable import AWSAppSync

class PlatfomAPIClientTests: XCTestCase {

    var instanceUnderTest: PlatformAPIClient!
    var mockAPIClient: SudoAPIClientMock!

    override func setUpWithError() throws {
        self.mockAPIClient = try SudoAPIClientMock()
        instanceUnderTest = PlatformAPIClient(appSyncClient: self.mockAPIClient)
    }

    func test_getReputation_rethrows_sudoAPIClientError() async {
        mockAPIClient.fetchErrorToThrow = TestError()
        let thrown = await captureThrownError {
            _ = try await instanceUnderTest.getReputation(url: "")
        }
        XCTAssertTrue(thrown is TestError, "expected error of type \(TestError.self), got \(String(describing: thrown.self))")
    }

    func test_getSiteReputation_throws_resultError() async {
        mockAPIClient.fetchResult = (nil, TestError())
        let thrown = await captureThrownError {
            _ = try await instanceUnderTest.getReputation(url: "")
        }

        XCTAssertTrue(thrown is TestError, "expected error of type \(TestError.self), got \(String(describing: thrown.self))")
    }

    func test_getSiteReputation_throws_graphQLErrors() async {
        let result = MockGraphQLResult(data: nil, errors: [GraphQLError("foobar")])
        mockAPIClient.fetchResult = (result, nil)
        let thrown = await captureThrownError {
            _ = try await instanceUnderTest.getReputation(url: "")
        }

        XCTAssertTrue(thrown is PlatformGraphQLError, "expected error of type \(TestError.self), got \(String(describing: thrown.self))")
    }

    func test_returnsAppSync_successResult() async throws {
        let mockedData = GraphQL.GetSiteReputationQuery.Data.init(getSiteReputation: .init(
            reputationStatus: .notmalicious,
            categories: []
        ))
        let result = MockGraphQLResult(data: mockedData, errors: nil)
        mockAPIClient.fetchResult = (result, nil)
        let reputation = try await instanceUnderTest.getReputation(url: "")
        XCTAssertEqual(String(describing: reputation), String(describing: mockedData))
    }
    
    func test_usesCache() async throws {
        let mockedData = GraphQL.GetSiteReputationQuery.Data.init(getSiteReputation: .init(
            reputationStatus: .notmalicious,
            categories: []
        ))
        let result = MockGraphQLResult(data: mockedData, errors: nil)
        mockAPIClient.fetchResult = (result, nil)
        
        // Asking the instance multiple times for the data should result in only
        // one call to the service.
        _ = try await instanceUnderTest.getReputation(url: "foo")
        _ = try await instanceUnderTest.getReputation(url: "foo")
        _ = try await instanceUnderTest.getReputation(url: "foo")
        XCTAssertEqual(mockAPIClient.fetchCallCount, 1)
        
        // Reset clears the cache and fetching results in another api call
        await instanceUnderTest.reset()
        _ = try await instanceUnderTest.getReputation(url: "foo")
        XCTAssertEqual(mockAPIClient.fetchCallCount, 2)
    }
}



