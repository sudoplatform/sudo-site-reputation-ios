//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation
import  SudoUser
import SudoConfigManager

final class SudoSiteReputationTests: XCTestCase {
    func testInitWithConfigFileMissing() throws {
        // We can't unit test init with config manager since the SDK config file
        // doesn't exist in the unit test bundle, but we do test the error case!

        typealias ConfigError = DefaultSudoSiteReputationClient.ConfigurationError
        let expected = ConfigError.failedToReadConfigurationFile

        XCTAssertThrowsError(
            try DefaultSudoSiteReputationClient(userClient: MockSudoUserClient()),
            "should throw invalid config error"
        ) { error in
            XCTAssertEqual(error as? ConfigError, expected)
        }
    }

    func testCanPassConfigDuringInit() {
        class MockConfig: SudoConfigManager {
            var getConfigSetCalled = false
            var getConfigSetParam: String = ""
            var getConfigSetReturn: [String: Any]?
            func getConfigSet(namespace: String) -> [String : Any]? {
                getConfigSetCalled = true
                getConfigSetParam = namespace
                return getConfigSetReturn
            }
        }

        typealias ConfigError = DefaultSudoSiteReputationClient.ConfigurationError
        let expected = ConfigError.failedToReadConfigurationFile

        XCTAssertThrowsError(
            try DefaultSudoSiteReputationClient(userClient: MockSudoUserClient()),
            "should throw invalid config error"
        ) { error in
            XCTAssertEqual(error as? ConfigError, expected)
        }
    }

    func testGetSiteReputation() throws {
        // Place a hardcoded malicious domain list in the cache.
        let cache = InMemoryCacheAccessor()
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
        try cache.put(list: list).get()

        // Instantiate the client.
        let client = DefaultSudoSiteReputationClient(
            staticDataBucket: "unit-test",
            userClient: MockSudoUserClient(),
            s3Client: MockS3Client(),
            cache: cache
        )

        // Verify that getSiteReputation() succeeds and returns the right results.
        let check = { (url: String, expectedMalicious: Bool) in
            let reputation = try client.getSiteReputation(url: url).get()
            XCTAssertEqual(reputation.isMalicious, expectedMalicious)
        }

        // check bare hosts
        try check("evil-website.example", true)
        try check("sudoplatform.com", false)
        try check("192.0.2.42", true)

        // check full HTTP URLs
        try check("https://evil-website.example/bad/page.html", true)
        try check("https://docs.sudoplatform.com/guides/getting-started", false)
        try check("http://192.0.2.42/signin.html", true)

        // check URL-ish strings
        try check("evil-website.example/", true)
        try check("evil-website.example/foo", true)
        try check("sudoplatform.com/", false)
        try check("docs.sudoplatform.com/foo", false)

        // check subdomains
        try check("villain.evil-website.example", true)
        try check("https://villain.evil-website.example/index.html", true)
        try check("evil-website.example.innocent.example", false)
        try check("notevil-website.example", false)
    }

    func testGetSiteReputationWithNoData() throws {
        // Instantiate the client with an empty cache.
        let client = DefaultSudoSiteReputationClient(
            staticDataBucket: "unit-test",
            userClient: MockSudoUserClient(),
            s3Client: MockS3Client(),
            cache: InMemoryCacheAccessor()
        )

        // Verify that check reports that reputation data is not present.
        let checkResult = client.getSiteReputation(url: "https://sudoplatform.com")
        switch checkResult {
        case .failure(.reputationDataNotPresent): break
        default: XCTFail("expected check to report no data.")
        }
    }

    func testGetSiteReputationAfterCacheLoadFails() throws {
        // Set up a faulted mock cache.
        struct UnitTestError: Error {}
        let mockCache = MockCacheAccessor()
        mockCache.getAllResult = .failure(.storageError(UnitTestError()))
        mockCache.getResult = .failure(.storageError(UnitTestError()))

        // Instantiate the client with the faulted cache.
        let client = DefaultSudoSiteReputationClient(
            staticDataBucket: "unit-test",
            userClient: MockSudoUserClient(),
            s3Client: MockS3Client(),
            cache: mockCache
        )

        // Verify that `getSiteReputation` reports that data is not present.
        let checkResult = client.getSiteReputation(url: "https://sudoplatform.com")
        switch checkResult {
        case .failure(.reputationDataNotPresent): break
        default: XCTFail("expected check to report no data.")
        }
    }

    func testClearStorage() throws {
        // Place a hardcoded malicious domain list in the cache.
        let cache = InMemoryCacheAccessor()
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
        try cache.put(list: list).get()

        // Instantiate the client.
        let client = DefaultSudoSiteReputationClient(
            staticDataBucket: "unit-test",
            userClient: MockSudoUserClient(),
            s3Client: MockS3Client(),
            cache: cache
        )

        // Clear storage.
        XCTAssertNoThrow(try client.clearStorage())

        // Verify that the cache is empty.
        XCTAssertTrue(try cache.get().get().isEmpty)
    }

    func testUpdate() throws {
        // Instantiate the client with an empty cache.
        let cache = InMemoryCacheAccessor()
        let s3Client = MockS3Client()
        let client = DefaultSudoSiteReputationClient(
            staticDataBucket: "unit-test",
            userClient: MockSudoUserClient(),
            s3Client: s3Client,
            cache: cache
        )

        // Set up S3 mocks to return new malicious domain list objects.
        let prefix = "/reputation-lists/MALICIOUSDOMAIN/"
        let key1 = prefix + "key1.txt"
        let body1 = """
some-evil-site.example
"""
        let key2 = prefix + "key-two.txt"
        let body2 = """
even-more.evil.example
evil2.test
"""

        s3Client._listObjectsV2 = { request, completion in
            XCTAssertEqual(request.bucket, "unit-test")
            XCTAssertEqual(request.prefix, prefix)
            completion?(MockS3Client.makeListOutput(keys: [key1, key2]), nil)
        }

        s3Client._getObject = { request, completion in
            switch (request.bucket, request.key) {
            case ("unit-test", key1):
                completion?(MockS3Client.makeGetOutput(body: body1), nil)
            case ("unit-test", key2):
                completion?(MockS3Client.makeGetOutput(body: body2), nil)
            default:
                let details = "'\(request.bucket ?? "")', '\(request.key ?? "")'"
                XCTFail("Unexpected bucket/key passed to getObject: \(details)")
            }
        }

        // Call update.
        let shouldUpdate = self.expectation(description: "update should complete")
        client.update { result in
            shouldUpdate.fulfill()

            switch result {
            case .success: break
            case .failure(let error): XCTFail("update should succeed \(error.localizedDescription)")
            }
        }
        wait(for: [shouldUpdate], timeout: 1)

        // Verify that `getSiteReputation` now reports expected results.
        let check = { (url: String, expectedMalicious: Bool) in
            let reputation = try client.getSiteReputation(url: url).get()
            XCTAssertEqual(reputation.isMalicious, expectedMalicious)
        }
        try check("even-more.evil.example", true)
        try check("sudoplatform.com", false)
        try check("https://some-evil-site.example/bad/page.html", true)
        try check("https://a.b.c.evil2.test", true)

        // Verify that the cache is populated
        XCTAssertEqual(try cache.get().get().count, 2)

        // Verify that `lastUpdatePerformedAt` is now recent.
        XCTAssertEqual(
            client.lastUpdatePerformedAt?.timeIntervalSince1970 ?? 0,
            Date().timeIntervalSince1970, accuracy: 5)
    }

    func testUpdateFailureFallsBackOnCache() throws {
        // Place a hardcoded malicious domain list in the cache.
        let cache = InMemoryCacheAccessor()
        let s3Client = MockS3Client()
        let contents =
"""
evil-website.example
192.0.2.42
"""
        let list = MaliciousDomainList(
            key: "/reputation-lists/MALICIOUSDOMAIN/unit-test.txt",
            eTag: "OUTDATED-unit-test", // NOTE: Outdated ETag.
            category: "MALICIOUSDOMAIN",
            name: "Unit Test Sample",
            body: Data(contents.utf8)
        )
        try cache.put(list: list).get()

        // Instantiate the client.
        let client = DefaultSudoSiteReputationClient(
            staticDataBucket: "unit-test",
            userClient: MockSudoUserClient(),
            s3Client: s3Client,
            cache: cache
        )

        // Set up S3 mocks to indicate a new version is available,
        // but fail to actually retrieve said new version.
        let prefix = "/reputation-lists/MALICIOUSDOMAIN/"
        s3Client._listObjectsV2 = { request, completion in
            XCTAssertEqual(request.bucket, "unit-test")
            XCTAssertEqual(request.prefix, prefix)
            completion?(MockS3Client.makeListOutput(keys: [list.key]), nil)
        }

        s3Client._getObject = { request, completion in
            struct UnitTestError: Error {}
            completion?(nil, UnitTestError())
        }

        // Call update.
        let shouldUpdate = self.expectation(description: "update should complete")
        var updateResult: Result<Void, SiteReputationUpdateError>!
        client.update { result in
            shouldUpdate.fulfill()
            updateResult = result
        }
        wait(for: [shouldUpdate], timeout: 1)

        // Verify that the old version of the list is fallen back to.
        XCTAssertEqual(try cache.get().get(), [list])

        // Verify that `update` reported a service error.
        switch updateResult {
        case .failure(.serviceError): break
        default: XCTFail("update should report a serviceError")
        }
    }

    func testUpdateUsesCacheIfUpToDate() throws {
        // Place a hardcoded malicious domain list in the cache.
        let cache = InMemoryCacheAccessor()
        let s3Client = MockS3Client()
        let contents =
"""
evil-website.example
192.0.2.42
"""
        let list = MaliciousDomainList(
            key: "/site-reputation/reputation-lists/MALICIOUSDOMAIN/unit-test.txt",
            eTag: "unit-test", // NOTE: Up-to-date ETag.
            category: "MALICIOUSDOMAIN",
            name: "Unit Test Sample",
            body: Data(contents.utf8)
        )
        try cache.put(list: list).get()

        // Instantiate the client.
        let client = DefaultSudoSiteReputationClient(
            staticDataBucket: "unit-test",
            userClient: MockSudoUserClient(),
            s3Client: s3Client,
            cache: cache
        )

        // Set up S3 mocks to respond that the list we have is up-to-date.
        // The client should skip calling getObject().
        s3Client._listObjectsV2 = { request, completion in
            completion?(MockS3Client.makeListOutput(keys: [list.key]), nil)
        }

        s3Client._getObject = { request, completion in
            XCTFail("getObject should not be called since the cache is up-to-date.")
        }

        // Call update.
        let shouldUpdate = self.expectation(description: "update should complete")
        client.update { result in
            shouldUpdate.fulfill()

            switch result {
            case .success: break
            case .failure(let error): XCTFail("update should succeed \(error.localizedDescription)")
            }
        }
        wait(for: [shouldUpdate], timeout: 1)

        // Verify that the cache still contains the current list.
        XCTAssertEqual(try cache.get().get(), [list])
    }

    func testClearStorageRacingWithUpdate() throws {
        // Instantiate the client.
        let mockS3Client = MockS3Client()
        let cache = InMemoryCacheAccessor()
        let client = DefaultSudoSiteReputationClient(
            staticDataBucket: "unit-test",
            userClient: MockSudoUserClient(),
            s3Client: mockS3Client,
            cache: cache
        )

        // Set up S3 mocks to control when the update process completes.
        let keys = ["key1", "key-two"]

        var completeListObjects: (() -> Void)!
        mockS3Client._listObjectsV2 = { request, completion in
            completeListObjects = {
                completion?(MockS3Client.makeListOutput(keys: keys), nil)
            }
        }

        var completeGetObjects: (() -> Void)!
        mockS3Client._getObject = { request, completion in
            let completePreviousGetObject = completeGetObjects
            completeGetObjects = {
                completePreviousGetObject?()
                completion?(MockS3Client.makeGetOutput(body: "evil.test"), nil)
            }
        }

        // Kick off an update that we will not complete until later.
        let shouldUpdate = expectation(description: "update should complete")
        var updateResult: Result<Void, SiteReputationUpdateError>!
        client.update { result in
            shouldUpdate.fulfill()
            updateResult = result
        }

        // Complete the "list objects" phase of update.
        completeListObjects()

        // Now clear storage.
        // If this fails due to `CacheAccessTimeoutError`, it is likely that the
        // `CacheToken` has not been released by closures created by `update`.
        try client.clearStorage()

        // Complete the "get object" phase of update.
        // We expect `clearStorage` to have cancelled the update process though.
        completeGetObjects()

        // Verify there is nothing in the cache.
        XCTAssertTrue(try cache.get().get().isEmpty)

        // Verify that update returned an error.
        wait(for: [shouldUpdate], timeout: 1)
        switch updateResult {
        case .failure(.cancelled): break /* expected */
        default: XCTFail("expected update cancellation error")
        }
    }

    func testUpdateRacingWithUpdate() {
        // Instantiate the client.
        let mockS3Client = MockS3Client()
        let cache = InMemoryCacheAccessor()
        let client = DefaultSudoSiteReputationClient(
            staticDataBucket: "unit-test",
            userClient: MockSudoUserClient(),
            s3Client: mockS3Client,
            cache: cache
        )

        // Set up S3 mocks to control when the update process completes.
        let keys = ["key1", "key-two"]

        var completeListObjects: (() -> Void)!
        mockS3Client._listObjectsV2 = { request, completion in
            completeListObjects = {
                completion?(MockS3Client.makeListOutput(keys: keys), nil)
            }
        }

        var completeGetObjects: (() -> Void)!
        mockS3Client._getObject = { request, completion in
            let completePreviousGetObject = completeGetObjects
            completeGetObjects = {
                completePreviousGetObject?()
                completion?(MockS3Client.makeGetOutput(body: "evil.test"), nil)
            }
        }

        // Kick off an update that we will not complete until later.
        let shouldUpdate = expectation(description: "update should complete")
        var updateResult: Result<Void, SiteReputationUpdateError>!
        client.update { result in
            shouldUpdate.fulfill()
            updateResult = result
        }

        // Call update again and verify that it reports "already in progress".
        let shouldUpdate2 = expectation(description: "update should complete 2")
        client.update { result in
            shouldUpdate2.fulfill()
            switch result {
            case .failure(.alreadyInProgress): break
            default: XCTFail("second update should report already in progress")
            }
        }
        wait(for: [shouldUpdate2], timeout: 1)

        // Complete the first call to update.
        completeListObjects()
        completeGetObjects()
        wait(for: [shouldUpdate], timeout: 1)

        // Verify that the first call to update succeeded.
        if case .failure(let error) = updateResult {
            XCTFail("expected update to succeed: \(error)")
        }
        XCTAssertEqual(
            client.lastUpdatePerformedAt?.timeIntervalSince1970 ?? 0,
            Date().timeIntervalSince1970, accuracy: 5)
    }

    func testUpdateDoesNotLoopInS3() {
        // Instantiate the client.
        let mockS3Client = MockS3Client()
        let cache = InMemoryCacheAccessor()
        let client = DefaultSudoSiteReputationClient(
            staticDataBucket: "unit-test",
            userClient: MockSudoUserClient(),
            s3Client: mockS3Client,
            cache: cache
        )

        // Set up an S3 mock that reports infinite pages of data.
        mockS3Client._listObjectsV2 = { request, completion in
            if request.continuationToken == nil {
                // First page.
                completion?(MockS3Client.makeListOutput(keys: ["key1"], moreData: true), nil)
            } else {
                // Else always respond with a non-nil nextContinuationToken.
                completion?(MockS3Client.makeListOutput(keys: [], moreData: true), nil)
            }
        }
        mockS3Client._getObject = { request, completion in
            XCTAssertEqual(request.bucket, "unit-test")
            XCTAssertEqual(request.key, "key1")
            completion?(MockS3Client.makeGetOutput(body: "evil.test"), nil)
        }

        // Call update.
        let shouldUpdate = expectation(description: "update should complete")
        var updateResult: Result<Void, SiteReputationUpdateError>!
        client.update { result in
            shouldUpdate.fulfill()
            updateResult = result
        }

        // Verify that update completes within the timeout
        // and succeeds with the data fetched so far.
        wait(for: [shouldUpdate], timeout: 2)
        if case .failure(let error) = updateResult {
            XCTFail("expected update to succeed \(error)")
        }
        XCTAssertEqual(try cache.get().get().count, 1)
    }
}
