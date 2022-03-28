//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Reputation data which can inform a decision on whether to warn
/// or block a user from visiting a potentially malicious website.
public struct SiteReputation {
    /// True if the site has been reported as malicious.
    public let isMalicious: Bool
}

/// A library of functions for querying the reputation of a website using the Sudo Platform Site Reputation service.
public protocol SudoSiteReputationClient {
    /// Checks the reputation of the provided URL.
    /// - Parameters:
    ///   - url: The URL that will be checked.
    func getSiteReputation(url: String) -> Result<SiteReputation, SiteReputationCheckError>

    /// Retrieves the latest site reputation data from the Sudo Platform Site Reputation service.
    /// - Parameters:
    ///   - completion: Called once when reputation data has been updated or an error occurs.
    func update(completion: @escaping (Result<Void, SiteReputationUpdateError>) -> Void)

    /// The timestamp of the site reputation data fetched by the last call to `update`,
    /// or `nil` if there is no site reputation data stored locally.
    var lastUpdatePerformedAt: Date? { get }

    /// Clears all locally cached data created by the SudoSiteReputation SDK.
    /// Cancels any in-progress calls to `update`, causing them to return an error.
    func clearStorage() throws
}

/// An error raised by `SudoSiteReputationClient.getSiteReputation`.
public enum SiteReputationCheckError: Error {
    /// Reputation data is not present. Call `update` to obtain the latest reputation data.
    case reputationDataNotPresent
}

/// An error raised by `SudoSiteReputationClient.update`.
public enum SiteReputationUpdateError: Error {
    /// An outstanding call to `update` or `clearStorage` is already in progress.
    case alreadyInProgress

    /// The update process was cancelled by a call to `clearStorage`.
    case cancelled

    /// An error occurred when accessing the Sudo Platform Site Reputation Service.
    case serviceError(_ underylingError: Error)
}
