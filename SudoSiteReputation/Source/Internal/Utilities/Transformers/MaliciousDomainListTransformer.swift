//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Transforms malicious domain lists that come from the service
/// into a site reputation ruleset.
enum MaliciousDomainListTransformer {
    static func transform(list: MaliciousDomainList) -> SiteReputationRuleset {

        let rules = list.domains.compactMap {
            return SiteReputationRule(urlString: $0)
        }

        return .init(key: list.key,
                     category: list.category,
                     name: list.name,
                     rules: rules)
    }
}
