//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// List of possible errors thrown by `S3DataSource` implementation.
enum S3DataSourceError: LocalizedError {

    /// Backed service is temporarily unavailable due to network or service availability issues.
    case serviceError(cause: Error)

    /// Attempted to access a non-existent S3 key
    case noSuchKey

    /// An S3 object with the given key is missing required metadata.
    case missingMetadata(key: String)

    /// The body was missing from the returned object.
    case dataMissing

    /// An error occurred while reading the body.
    case failedToReadData(cause: Error)

    // MARK: - Conformance: LocalizedError

    var errorDescription: String? {
        switch self {
        case .serviceError(let underlyingError):
            return L10n.SiteReputation.Errors.S3DataSourceError.serviceError(underlyingError.localizedDescription)
        case .noSuchKey:
            return L10n.SiteReputation.Errors.S3DataSourceError.noSuchKey
        case .missingMetadata(let key):
            return L10n.SiteReputation.Errors.S3DataSourceError.missingMetadata(key)
        case .dataMissing:
            return L10n.SiteReputation.Errors.S3DataSourceError.dataMissing
        case .failedToReadData(let underlyingError):
            return L10n.SiteReputation.Errors.S3DataSourceError.failedToReadData(underlyingError.localizedDescription)
        }
    }
}
