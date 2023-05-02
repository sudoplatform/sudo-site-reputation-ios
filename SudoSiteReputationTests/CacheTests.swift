//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation

final class CacheTests: XCTestCase {

    func testInsertOverwritesValue() {
        let instance = Cache<String, String>()
        
        XCTAssertNil(instance["foo"])
        instance["foo"] = "foo"
        XCTAssertEqual(instance["foo"], "foo")
        
        instance["foo"] = "bar"
        XCTAssertEqual(instance["foo"], "bar")
    }
    
    func testInsertAndRemove() {
        let instance = Cache<String, String>()
        
        XCTAssertNil(instance.value(forKey: "foo"))
        instance.set(value: "foo", forKey: "foo")
        XCTAssertEqual(instance["foo"], "foo")
        
        instance.removeValue(forKey: "foo")
        XCTAssertNil(instance.value(forKey: "foo"))
    }
}
