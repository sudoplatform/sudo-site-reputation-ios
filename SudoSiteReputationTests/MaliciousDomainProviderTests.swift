//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation
import SudoLogging
import SudoUser

class MaliciousDomainProviderTests: XCTestCase {

    var s3Client: MockS3Client!
    var serviceDataCache: InMemoryServiceDataCache!
    var logger: Logger!
    var instanceUnderTest: MaliciousDomainListProvider!

    override func setUpWithError() throws {
        self.s3Client = MockS3Client()
        self.serviceDataCache = InMemoryServiceDataCache()
        self.logger = Logger(identifier: "unit.test", driver: NSLogDriver(level: .debug))
        self.instanceUnderTest = MaliciousDomainListProvider(staticDataBucket: "",
                                                             s3: s3Client,
                                                             cache: serviceDataCache,
                                                             logger: logger)
    }

    func testFetchMaliciousDomainLists_withListsInCache_willReturnCachedLists() async throws {
        // Setup Mocks
        let body1 = """
some-evil-site.example
"""

        guard let body1Data = body1.data(using: .utf8) else {
            XCTFail()
            throw "Body Data not unwrapped."
        }

        let result: MaliciousDomainList = SudoSiteReputation.MaliciousDomainList(key: "/reputation-lists/key1.txt",
                                                                                 eTag: "unit-test",
                                                                                 category: "MALICIOUSDOMAIN",
                                                                                 name: "Unit Test Sample",
                                                                                 body: body1Data)
        _ = await serviceDataCache.put(list: result)

        guard let fetchedList = await instanceUnderTest.fetchMaliciousDomainLists() else {
            XCTFail()
            throw "Unable to fetch result"
        }

        XCTAssertEqual(fetchedList, [result])
    }

    func testFetchMaliciousDomainLists_withEmptyCache_willReturnNil() async throws {
        let fetchedList = await instanceUnderTest.fetchMaliciousDomainLists()

        XCTAssertEqual(fetchedList, nil)
    }

    func testUpdate() async throws {
        // Set up S3 Mocks to return new malicious domain list objects.
        let prefix = "/reputation-lists/"
        let key1 = prefix + "key1.txt"
        let body1 = """
some-evil-site.example
"""
        let key2 = prefix + "key-two.txt"
        let body2 = """
even-more.evil.example
evil2.test
"""
        let key3 = prefix + "keyThree.txt"
        let body3 = """
that-one.evil.example
evil2.test
"""
        let key4 = prefix + "fourthKey.txt"
        let body4 = """
the-final.evil.example
evil2.test
"""

        s3Client.mockKeys = [key1, key2, key3, key4]
        s3Client.mockBodies = [body1, body2, body3, body4]
        s3Client.listObjectsV2Request?.bucket = "unit-test"
        s3Client.listObjectsV2Request?.prefix = prefix

        guard let body3Data = body3.data(using: .utf8),
              let body4Data = body4.data(using: .utf8)else {
            XCTFail()
            throw "Body Data not unwrapped."
        }

        // The eTag here is deliberately mismatched.
        let list3 = SudoSiteReputation.MaliciousDomainList(key: key3,
                                                           eTag: "test-unit",
                                                           category: "MALICIOUSDOMAIN",
                                                           name: "Unit Test Sample",
                                                           body: body3Data)
        // This mock is to be placed in the cache and return properly in order to test skipping the download
        let list4 = SudoSiteReputation.MaliciousDomainList(key: key4,
                                                           eTag: "unit-test",
                                                           category: "MALICIOUSDOMAIN",
                                                           name: "Unit Test Sample",
                                                           body: body4Data)

        // Setting the mock cache results.
        _ = await self.serviceDataCache.put(list: list3)
        _ = await self.serviceDataCache.put(list: list4)

        // Run the update function to put the keys in the cache.
        try await instanceUnderTest.update()

        // Check the cache for the keys.
        let lastUpdate = await instanceUnderTest.cache.lastUpdatePerformedAt?.timeIntervalSince1970 ?? 0
        XCTAssertEqual(lastUpdate, Date().timeIntervalSince1970, accuracy: 5)

        // Verify that the cache is populated
        let cacheCount = try await instanceUnderTest.cache.get().get().count
        XCTAssertEqual(cacheCount, 4)

        // The getObject method should only be called 3 times. Twice for the keys which weren't in the cache, and once for the key3 which had a mismatched eTag and needed to be updated.
        XCTAssertEqual(s3Client.getObjectCalled, 3)
    }

    func testUpdateDoesNotLoopInS3() async throws {
        let body1 = "body1"
        
        s3Client.mockKeys = ["key1"]
        s3Client.mockBodies = [body1]
        s3Client.listObjectsV2Request?.bucket = "unit-test"
        s3Client.listObjectsV2Request?.prefix = "/reputation-lists/"

        //This sets the continuation token and makes the recursive function run continuously.
        s3Client.mockMoreData = true

        guard let body1Data = body1.data(using: .utf8) else {
            XCTFail()
            throw "Body Data not unwrapped."
        }

        let result: MaliciousDomainList = SudoSiteReputation.MaliciousDomainList(key: "/reputation-lists/key1.txt",
                                                                                    eTag: "unit-test",
                                                                                    category: "MALICIOUSDOMAIN",
                                                                                    name: "Unit Test Sample",
                                                                                    body: body1Data)
        _ = await serviceDataCache.put(list: result)

        // Run the update function to put the keys in the cache.
        try await instanceUnderTest.update()

        // Check the cache to see that the update function finished running instead of ending in an infinite loop.
        let lastUpdate = await instanceUnderTest.cache.lastUpdatePerformedAt?.timeIntervalSince1970 ?? 0
        XCTAssertEqual(lastUpdate, Date().timeIntervalSince1970, accuracy: 5)
        // The listObjects() function will loop 10 times once it's been called, therefore it should run 11 times.
        XCTAssertEqual(s3Client.listObjectsV2Called, 11)
    }
}
