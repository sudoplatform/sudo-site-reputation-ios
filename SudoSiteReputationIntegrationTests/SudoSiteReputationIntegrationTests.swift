//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SudoKeyManager
import SudoUser
@testable import SudoSiteReputation

class SudoSiteReputationIntegrationTests: IntegrationTestBase {

    var client: DefaultSudoSiteReputationClient!

    override func setUpWithError() throws {
        try super.setUpWithError()

        self.client = try DefaultSudoSiteReputationClient(
            userClient: userClient
        )


        let setupExpectation = self.expectation(description: "wait for setup")
        Task {
            try await client.clearStorage()
            setupExpectation.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
    }

    override func tearDownWithError() throws {
        let tearDownExpectation = self.expectation(description: "wait for teardown")
        Task {
            try await client.clearStorage()
            tearDownExpectation.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
    }

    func testCheckSiteReputation() async throws {
        // Perform a check before `update` and verify that it fails.
        do {
            _ = try await client.getSiteReputation(url: "https://sudoplatform.com")
            XCTFail("check before `update` should report no data")
        } catch {
            let lastUpdate = await client.lastUpdatePerformedAt()
            XCTAssertEqual(lastUpdate, nil)
        }

        // Perform an `update`.
        try await client.update()

        // last updated at was set.
        var firstUpdateTimestamp = await client.lastUpdatePerformedAt()
        XCTAssertNotNil(firstUpdateTimestamp)

        // Update a second time, just to make sure we can.
        // If this fails with alreadyInProgress, it is likely that the
        // previous update() call retained the lock on the shared Cache.
        try await client.update()

        // Check that updated at was bumped from the previous call.
        let secondUpdateTimestamp = await client.lastUpdatePerformedAt()!
        XCTAssertNotEqual(firstUpdateTimestamp!.timeIntervalSince1970, secondUpdateTimestamp.timeIntervalSince1970, accuracy: 0.01)

        // Check that known non-malicious sites have good reputation.
        let check = { (url: String, expectedMalicious: Bool) in
            let reputation = try await self.client.getSiteReputation(url: url)
            XCTAssertEqual(reputation.isMalicious, expectedMalicious)
        }
        try await check("https://docs.sudoplatform.com/guides/getting-started", false)
        try await check("anonyome.com", false)

        // NOTE: These tests rely on the environment we are using to have set up
        // the site reputation service with a test malicious domain list.
        // If these checks fail, the Site Reputation Service may not be set up.

//        let siteReputationServiceIsConfigured = false
//        if siteReputationServiceIsConfigured {
//            try await check("192.0.2.42", true)
//            try await check("https://subdomain.evil-site.example/some/path.php", true)
//        }
    }

    func test_all_maliciousDomains_are_malicious() async throws {
        // Perform an `update`.
        try await client.update()
        NSLog("Checking all domain lists")

        // get all the malicious domains pulled from the service.
        let domainList = await client.maliciousDomainListProvider.fetchMaliciousDomainLists() ?? []
        XCTAssertTrue(domainList.count != 0)

        // loop over all the lists
        for (index, list) in domainList.enumerated() {
            NSLog("Checking items from list \(index+1)/ \(domainList.count).")
            NSLog("\(list.name) contains \(list.domains.count) items")

            let domains = list.domains
            XCTAssertTrue(domains.count != 0)

            // Check all malicious domains from the list are considered malicious by the engine.
            for domain in domains {

                // Filter comments from the lists
                if domain.hasPrefix("#") || domain.isEmpty { continue }

                do {
                    let result = try await self.client.getSiteReputation(url: domain)
                    XCTAssertTrue(result.isMalicious, "Expected \(domain) to be malicious")
                }
                catch {
                    XCTFail("Found a domain reported an error")
                    NSLog("Found a domain reported an error while checking \(domain)")
                }
            }
        }
    }
}
