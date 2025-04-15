//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

extension SiteReputation {

    init(graphQL: GraphQL.Reputation) {
        /// Note: there is a bug with the Amplify codegen types where enum properties cannot be accessed directly or it will cause a crash.
        /// The site reputation enum is manually extracted from the snapshot here until this bug is fixed.
        /// https://github.com/aws-amplify/amplify-swift/issues/3953
        var reputationStatus: ReputationStatus = .unknown
        if let reputationStatusRawValue = graphQL.snapshot["reputationStatus"] as? String {
            switch GraphQL.ReputationStatus(rawValue: reputationStatusRawValue) {
            case .malicious:
                reputationStatus = .malicious
            case .notmalicious:
                reputationStatus = .notMalicious
            case .unknown, .none:
                reputationStatus = .unknown
            }
        }
        self.init(status: reputationStatus, categories: graphQL.categories)
    }
}
