//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation

class SiteReputationRulesetTests: XCTestCase {

    func test_init_will_assign_properties_correctly() {

        let key = "Key"
        let category = "Category"
        let name = "Name"
        let rules = [SiteReputationRule(host: "foo.bar.com", path: ""),
                     SiteReputationRule(host: "malware.com", path: "index.html")]

        let instance = SiteReputationRuleset(key: key, category: category, name: name, rules: rules)
        XCTAssertEqual(instance.key, key)
        XCTAssertEqual(instance.category, category)
        XCTAssertEqual(instance.name, name)
        XCTAssertEqual(instance.lookupTable.count, rules.count)
    }
}
