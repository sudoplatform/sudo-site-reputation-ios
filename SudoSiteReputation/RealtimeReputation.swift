//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Reputation data returned from client
public struct RealtimeReputation {
    
    public init(
        categories: [Int],
        confidence: Double?,
        isMalicious: MaliciousState,
        scope: RealtimeReputation.Scope?,
        status: RealtimeReputation.Status
    ) {
        self.categories = categories
        self.confidence = confidence
        self.isMalicious = isMalicious
        self.scope = scope
        self.status = status
    }
    
    /// Search status
     public enum Status {
        /// URI not found in dataset
        case notFound
        /// URI found in dataset
        case success
    }
    
    /// Scope of the search performed
    public enum Scope {
       /// matched on domain
       case domain
       /// matched on path
       case path
   }
    
    /// Represents the malicious calculation from the service
    public enum MaliciousState {
        /// site is know to be malicious.
        case malicious
        /// site is not know to be malicious.
        case notMalicious
        /// no site data available to make a calculation.
        case unknown
    }
    
    /// Numerical categories the site is categorized by.
    public let categories: [Int]

    /// The algorithmic calculation of the confidence of the rating */
    public let confidence: Double?

    /// Returns `true` if malicious, `false` if not, and `undefined` if unknown.
    public let isMalicious: MaliciousState

    /// The scope of the search
    public let scope: Scope?

    /// The returned result of the lookup for the site. If .success you can expect the other properties to be non nil.
    public let status: Status
}

// MARK: Transformers.

// These accept the value from the graphQL object and return the transformed type.
extension RealtimeReputation {
    
    init(graphQL: GraphQL.Reputation) {
        let categories = graphQL.categories.compactMap({Int($0.id)})
        self.init(
            // graphql entity is a simple wrapper and id is the category value
            categories: categories,
            confidence: graphQL.confidence,
            isMalicious: MaliciousState(graphQL: graphQL.isMalicious),
            scope: graphQL.scope.flatMap(Scope.init(graphQL:)),
            status: Status(graphQL: graphQL.status)
        )
    }
}

// These sub objects accept the value from the graphQL object and return the transformed type as well.
extension RealtimeReputation.Scope {
    init?(graphQL: GraphQL.Scope) {
        switch graphQL {
        case .domain: self = .domain
        case .path: self = .path
        default: return nil
        }
    }
}

extension RealtimeReputation.Status {
    init(graphQL: GraphQL.ReputationStatus) {
        switch graphQL {
        case .success: self = .success
        case .notFound: self = .notFound
        default: self = .notFound
        }
    }
}

extension RealtimeReputation.MaliciousState {
    init(graphQL: Bool?) {
        // Convert `Bool?` from graphQL to one of the MaliciousState values.
        self = graphQL.map({$0 ? .malicious : .notMalicious}) ?? .unknown
    }
}
