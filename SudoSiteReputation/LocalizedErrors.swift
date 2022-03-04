//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import protocol Foundation.LocalizedError

// MARK: - SudoSiteReputationClient

extension DefaultSudoSiteReputationClient.ConfigurationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToReadConfigurationFile:
            return "Failed to read sudoplatformconfig.json."
        case .missingKey:
            return "sudoplatformconfig.json is missing a required key."
        case .missingCachesDirectory:
            return "Caches directory not found."
        }
    }
}

extension SiteReputationCheckError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .reputationDataNotPresent:
            return "Reputation data is not present. Call `update` or `loadCachedData` to obtain the latest reputation data."
        }
    }
}

extension SiteReputationUpdateError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .alreadyInProgress:
            return "An outstanding call to `update` or `clearStorage` is already in progress."
        case .cancelled:
            return "The update process was cancelled by a call to `clearStorage`."
        case .serviceError(let underlyingError):
            return "Failed to access the Site Reputation Service: \(underlyingError.localizedDescription)"
        }
    }
}

// MARK: - S3DataSource

extension S3Error: LocalizedError {
    var errorDescription: String? {
        let reason = underlyingError.map { ": \($0.localizedDescription)" } ?? ""
        return "Failed to access S3\(reason)"
    }
}

extension S3DataSourceNonFatal: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .tooManyLists:
            return "Exceeded maximum number of pages of S3 data."
        case .missingMetadata(let key):
            return "S3 object with key '\(key)' is missing required metadata."
        }
    }
}

extension ListMaliciousDomainListsError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .s3Error(let error):
            return error.localizedDescription
        }
    }
}

extension FetchMaliciousDomainListError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .s3Error(let error):
            return error.localizedDescription
        case .missingMetadata:
            return "S3 object is missing required metadata."
        }
    }
}

// MARK: - Storage

extension CacheAccessError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .storageError(let underlyingError):
            return "An error occurred when accessing the persistent storage: \(underlyingError)"
        case .codableError(let underlyingError):
            return "An error occurred when encoding or decoding cached data: \(underlyingError)"
        }
    }
}
