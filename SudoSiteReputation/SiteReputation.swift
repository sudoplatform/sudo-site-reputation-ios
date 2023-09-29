//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Reputation data returned from client
public struct SiteReputation {
    
    public init(
        status: SiteReputation.ReputationStatus,
        categories: [String]
    ) {
        self.status = status
        self.categories = categories
    }
    
    /// Search status
     public enum ReputationStatus {
         // URI not in dataset as not malicious
         case notMalicious
         // URI found in dataset as malicious
         case malicious
         // URI not found in the dataset
         case unkown
    }

    /// The returned result of the lookup for the site. If .success you can expect the other properties to be non nil.
    public let status: ReputationStatus
    
    /// Categorization of the site
    public let categories: [String]
}

// MARK: Transformers.

// These accept the value from the graphQL object and return the transformed type.
extension SiteReputation {
    
    init(graphQL: GraphQL.Reputation) {
        self.init(
            status: ReputationStatus(graphQL: graphQL.reputationStatus),
            categories: graphQL.categories
        )
    }
}

extension SiteReputation.ReputationStatus {
    init(graphQL: GraphQL.ReputationStatus) {
        // The graphQL `ReputationStatus` derrived from the schema gets a `.unknown(String)`
        // case in the graphQL codegen even though it's not in the schema. This was
        // removed from the schema because of naming conflict when codegen automatically adds a second
        // unknown case
        switch graphQL {
        case .malicious: self = .malicious
        case .notmalicious: self = .notMalicious
        default: self = .unkown
        }
    }
}

extension SiteReputation.ReputationStatus: Equatable {
    
}

