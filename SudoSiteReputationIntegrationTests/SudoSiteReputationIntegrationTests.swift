//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SudoKeyManager
import SudoUser
@testable import SudoSiteReputation

class SudoSiteReputationIntegrationTests: XCTestCase {

    var client: DefaultSudoSiteReputationClient!
    var userClient: SudoUserClient!

    override func setUpWithError() throws {
        // Initialize the client.
        let namespace = "srs-integration-test"
        self.userClient = try DefaultSudoUserClient(keyNamespace: namespace)
        self.client = try DefaultSudoSiteReputationClient(
            userClient: userClient,
            storageNamespace: namespace
        )

        let setupExpectation = self.expectation(description: "wait for setup")
        Task {
            try await client.clearStorage()
            try await userClient.reset()

            let isRegistered = try await userClient.isRegistered()
            XCTAssertFalse(isRegistered)

            try await register(userClient: userClient)
            try await signIn(userClient: userClient)
            setupExpectation.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
    }

    override func tearDownWithError() throws {
        let tearDownExpectation = self.expectation(description: "wait for teardown")
        Task {
            try await deregister(userClient: userClient)
            try await userClient.reset()
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

        // Update a second time, just to make sure we can.
        // If this fails with alreadyInProgress, it is likely that the
        // previous update() call retained the lock on the shared Cache.
        try await client.update()

        // Verify that `lastUpdatePerformedAt` has been bumped.
        let lastUpdate = await client.lastUpdatePerformedAt()
        XCTAssertEqual(
            lastUpdate?.timeIntervalSince1970 ?? 0,
            Date().timeIntervalSince1970,
            accuracy: 5
        )

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

    private func register(userClient: SudoUserClient) async throws {
        let bundle = Bundle.main
        guard let testKeyPath = bundle.path(forResource: "register_key", ofType: "private"),
              let testKeyIdPath = bundle.path(forResource: "register_key", ofType: "id")
        else {
            XCTFail("Missing register_key.private or register_key.id. Please make sure these files are present in ${PROJECT_DIR}/config and are copied to the testing bundle.")
            return
        }

        let testKey = try String(contentsOfFile: testKeyPath)
        let testKeyId = try String(contentsOfFile: testKeyIdPath)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let keyManager = LegacySudoKeyManager(serviceName: "com.sudoplatform.appservicename",
                                            keyTag: "com.sudoplatform",
                                            namespace: "test")
        let authProvider = try TESTAuthenticationProvider(name: "testRegisterAudience",
                                                          key: testKey,
                                                          keyId: testKeyId,
                                                          keyManager: keyManager)
        _ = try await userClient.registerWithAuthenticationProvider(authenticationProvider: authProvider,
                                                                    registrationId: "srs-int-test-\(Date())")
    }

    private func signIn(userClient: SudoUserClient) async throws {
        do {
            _ = try await userClient.signInWithKey()
        } catch {
            print("warning: Failed to signIn: \(error)")
        }
    }

    private func deregister(userClient: SudoUserClient) async throws {
        do {
            _ = try await userClient.deregister()
        } catch {
            print("warning: Failed to deregister: \(error)")
        }
    }
}
