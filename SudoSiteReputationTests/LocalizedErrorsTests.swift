//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation

struct TestError: Error, LocalizedError {
    let errorDescription: String? = "test error"
}

private struct TestUnlocalizedError: Error {}

class LocalizedErrorsTests: XCTestCase {
    let defaultDescription = "The operation couldn’t be completed."
    private func assertErrorIsLocalized(_ error: LocalizedError) {
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.localizedDescription.contains(defaultDescription))
    }

    func test_assertErrorIsLocalized() {
        let localized = TestError().localizedDescription
        let unlocalized = TestUnlocalizedError().localizedDescription
        XCTAssertTrue(unlocalized.contains(defaultDescription))
        XCTAssertFalse(localized.contains(defaultDescription))
    }

    // MARK: - SudoSiteReputationClient

    func test_ConfigurationError() {
        [
            LegacySiteReputationClientConfig.ConfigurationError.failedToReadConfigurationFile,
            LegacySiteReputationClientConfig.ConfigurationError.missingCachesDirectory,
            LegacySiteReputationClientConfig.ConfigurationError.missingKey,
        ].forEach(assertErrorIsLocalized)
    }

    func test_SiteReputationCheckError() {
        [
            LegacySiteReputationCheckError.reputationDataNotPresent,
        ].forEach(assertErrorIsLocalized)
    }

    func test_SiteReputationUpdateError() {
        [
            LegacySiteReputationUpdateError.alreadyInProgress,
            LegacySiteReputationUpdateError.cancelled,
            LegacySiteReputationUpdateError.serviceError(TestError()),
        ].forEach(assertErrorIsLocalized)
    }

    // MARK: - S3DataSource

    func test_S3Error() {
        [
            S3Error(underlyingError: TestError()),
            S3Error(underlyingError: nil),
        ].forEach(assertErrorIsLocalized)
    }

    func test_S3DataSourceNonFatal() {
        [
            S3DataSourceNonFatal.tooManyLists,
            S3DataSourceNonFatal.missingMetadata(key: "Test Key"),
        ].forEach(assertErrorIsLocalized)
    }

    func test_ListMaliciousDomainListsError() {
        [
            ListMaliciousDomainListsError.s3Error(S3Error(underlyingError: TestError())),
        ].forEach(assertErrorIsLocalized)
    }

    func test_FetchMaliciousDomainListError() {
        [
            FetchMaliciousDomainListError.s3Error(S3Error(underlyingError: TestError())),
            FetchMaliciousDomainListError.missingMetadata,
        ].forEach(assertErrorIsLocalized)
    }

    // MARK: - Storage

    func test_CacheAccessError() {
        [
            CacheAccessError.storageError(TestError()),
            CacheAccessError.codableError(TestError()),
        ].forEach(assertErrorIsLocalized)
    }
}
