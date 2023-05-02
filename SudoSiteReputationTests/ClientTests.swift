//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation
import AWSS3
import SudoUser
import SudoConfigManager

final class SudoSiteReputationTests: XCTestCase {

    var s3Client: MockS3Client!
    var serviceDataCache: InMemoryServiceDataCache!
    var userClient: MockSudoUserClient!
    var instanceUnderTest: DefaultLegacySiteReputationClient!

    override func setUpWithError() throws {
        s3Client = MockS3Client()
        serviceDataCache = InMemoryServiceDataCache()
        userClient = MockSudoUserClient()
        instanceUnderTest = DefaultLegacySiteReputationClient(staticDataBucket: "unit-test",
                                                            userClient: userClient,
                                                            s3Client: s3Client,
                                                            cache: serviceDataCache)
    }

    override func tearDownWithError() throws {
        Task{ await serviceDataCache.reset() }
    }

    func testInitWithConfigFileMissing() async throws {
        // We can't unit test init with config manager since the SDK config file
        // doesn't exist in the unit test bundle, but we do test the error case!

        typealias ConfigError = LegacySiteReputationClientConfig.ConfigurationError
        let expected = ConfigError.failedToReadConfigurationFile

        XCTAssertThrowsError(
            try DefaultLegacySiteReputationClient(userClient: MockSudoUserClient()),
            "should throw invalid config error"
        ) { error in
            XCTAssertEqual(error as? ConfigError, expected)
        }
    }

    func testCanPassConfigDuringInit() {
        class MockConfig: SudoConfigManager {
            // This function is required for the Mock to conform to SudoConfigManager
            func validateConfig() async throws {}

            var getConfigSetCalled = false
            var getConfigSetParam: String = ""
            var getConfigSetReturn: [String: Any]?
            func getConfigSet(namespace: String) -> [String : Any]? {
                getConfigSetCalled = true
                getConfigSetParam = namespace
                return getConfigSetReturn
            }
        }

        typealias ConfigError = LegacySiteReputationClientConfig.ConfigurationError
        let expected = ConfigError.failedToReadConfigurationFile

        XCTAssertThrowsError(
            try DefaultLegacySiteReputationClient(userClient: MockSudoUserClient()),
            "should throw invalid config error"
        ) { error in
            XCTAssertEqual(error as? ConfigError, expected)
        }
    }

    func testSudoSiteReputationClientConfig_passInConfigWithNoIdentityService_willThrowMissingKeyError() {
        class MockConfig: SudoConfigManager {
            // Will return empty key.
            func getConfigSet(namespace: String) -> [String : Any]? { return nil }
            func validateConfig() async throws {}
        }

        typealias ConfigError = LegacySiteReputationClientConfig.ConfigurationError
        let expected = ConfigError.missingKey

        XCTAssertThrowsError(
            try LegacySiteReputationClientConfig(userClient: MockSudoUserClient(), configManager: MockConfig()),
            "should throw invalid config error"
        ) { error in
            XCTAssertEqual(error as? ConfigError, expected)
        }
    }

    func testSudoSiteReputationClientConfig_passInConfigWithNoSudoSiteReputationService_willThrowMissingKeyError() {
        class MockConfig: SudoConfigManager {
            // Will return empty key.
            var identityServicePassed = false
            func getConfigSet(namespace: String) -> [String : Any]? {
                if namespace == "identityService" {
                    identityServicePassed = true
                    return [ "poolId" : "", "identityPoolId" : ""]
                }
                return nil
            }

            func validateConfig() async throws {}
        }
        let configMock = MockConfig()

        typealias ConfigError = LegacySiteReputationClientConfig.ConfigurationError
        let expected = ConfigError.missingKey

        XCTAssertThrowsError(
            try LegacySiteReputationClientConfig(userClient: MockSudoUserClient(), configManager: configMock),
            "should throw invalid config error"
        ) { error in
            XCTAssertTrue(configMock.identityServicePassed)
            XCTAssertEqual(error as? ConfigError, expected)
        }
    }

    func testSudoSiteReputationClientInit_passInConfig_willInit() {
        class MockConfig: SudoConfigManager {
            // Will return empty key.
            var identityServicePassed = false
            func getConfigSet(namespace: String) -> [String : Any]? {
                if namespace == "identityService" {
                    identityServicePassed = true
                    return [ "poolId" : "", "identityPoolId" : ""]
                }
                if namespace == "siteReputationService" {
                    identityServicePassed = true
                    // The region appears to need to be set to one of a number of very specific strings. In this case, `us-east-1` is one of them.
                    return [ "region" : "us-east-1", "bucket" : ""]
                }
                return nil
            }

            func validateConfig() async throws {}
        }
        let configMock = MockConfig()

        XCTAssertNoThrow(
            try LegacySiteReputationClientConfig(userClient: MockSudoUserClient(), configManager: configMock)
        )
    }

    func testGetSiteReputation() async throws {
        // Place a hardcoded malicious domain list in the cache.
        let contents =
"""
evil-website.example
192.0.2.42
"""
        let list = MaliciousDomainList(
            key: "/site-reputation/reputation-lists/MALICIOUSDOMAIN/unit-test.txt",
            eTag: "asdfasdf-unit-test",
            category: "MALICIOUSDOMAIN",
            name: "Unit Test Sample",
            body: Data(contents.utf8)
        )
        try await serviceDataCache.put(list: list).get()

        await instanceUnderTest.loadCachedData()

        // Verify that getSiteReputation() succeeds and returns the right results.
        let check = { (url: String, expectedMalicious: Bool) in
            let reputation = try await self.instanceUnderTest.getSiteReputation(url: url)
            XCTAssertEqual(reputation.isMalicious, expectedMalicious, "expect \(url) to be malicious")
        }

        // check bare hosts
        try await check("evil-website.example", true)
        try await check("sudoplatform.com", false)
        try await check("192.0.2.42", true)

        // check full HTTP URLs
        try await check("https://evil-website.example/bad/page.html", true)
        try await check("https://docs.sudoplatform.com/guides/getting-started", false)
        try await check("http://192.0.2.42/signin.html", true)

        // check URL-ish strings
        try await check("evil-website.example/", true)
        try await check("evil-website.example/foo", true)
        try await check("sudoplatform.com/", false)
        try await check("docs.sudoplatform.com/foo", false)

        // check subdomains
        try await check("villain.evil-website.example", true)
        try await check("https://villain.evil-website.example/index.html", true)
        try await check("evil-website.example.innocent.example", false)
        try await check("notevil-website.example", false)
    }

    func testGetSiteReputationWithNoData() async throws {
        await instanceUnderTest.loadCachedData()
        // Verify that check reports that reputation data is not present.
        do {
            _ = try await instanceUnderTest.getSiteReputation(url: "https://sudoplatform.com")
            XCTFail("expected check to report no data.")
        } catch {
            XCTAssertEqual(error as! LegacySiteReputationCheckError, LegacySiteReputationCheckError.reputationDataNotPresent)
        }
    }

    func testGetSiteReputationAfterCacheLoadFails() async throws {
        // Set up a faulted mock cache.
        struct UnitTestError: Error {}

        // Instantiate the client with the faulted cache.
        let client = DefaultLegacySiteReputationClient(
            staticDataBucket: "unit-test",
            userClient: MockSudoUserClient(),
            s3Client: MockS3Client(),
            cache: serviceDataCache
        )

        // Verify that `getSiteReputation` reports that data is not present.
        do {
            _ = try await client.getSiteReputation(url: "https://sudoplatform.com")
            XCTFail("expected check to report no data.")
        } catch {
            XCTAssertEqual(error as! LegacySiteReputationCheckError, LegacySiteReputationCheckError.reputationDataNotPresent)
        }
    }

    func testClearStorage() async throws {
        // Place a hardcoded malicious domain list in the cache.
        let contents =
"""
evil-website.example
192.0.2.42
"""
        let list = MaliciousDomainList(
            key: "/site-reputation/reputation-lists/MALICIOUSDOMAIN/unit-test.txt",
            eTag: "asdfasdf-unit-test",
            category: "MALICIOUSDOMAIN",
            name: "Unit Test Sample",
            body: Data(contents.utf8)
        )
        try await serviceDataCache.put(list: list).get()

        await instanceUnderTest.loadCachedData()

        // Clear storage.
        try await instanceUnderTest.clearStorage()

        // Verify that the cache is empty.
        let cacheLists = try await serviceDataCache.get().get()
        XCTAssertTrue(cacheLists.isEmpty)
    }
}
