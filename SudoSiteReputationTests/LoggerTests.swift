//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import SudoSiteReputation
import SudoLogging

class LoggerTests: XCTestCase {

    /// Test a property of the shared logger to satisfy sonarqube.
    func testPerformanceExample() throws {
        XCTAssertEqual(Logger.siteReputationLogger.logIdentifier, "com.sudoplatform.sitereputation")
    }
}
