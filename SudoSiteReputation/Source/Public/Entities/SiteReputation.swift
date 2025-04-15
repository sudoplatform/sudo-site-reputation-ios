//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Reputation data returned from client
public struct SiteReputation {
    
    // MARK: - Supplementary

    /// Search status
    public enum ReputationStatus: Equatable {
         /// URI not in dataset as not malicious
         case notMalicious
         /// URI found in dataset as malicious
         case malicious
         /// URI not found in the dataset
         case unknown
    }

    // MARK: - Properties

    /// The returned result of the lookup for the site. If .success you can expect the other properties to be non nil.
    public let status: ReputationStatus

    /// Categorization of the site
    public let categories: [String]

    // MARK: - Lifecycle

    public init(status: SiteReputation.ReputationStatus, categories: [String]) {
        self.status = status
        self.categories = categories
    }
}
