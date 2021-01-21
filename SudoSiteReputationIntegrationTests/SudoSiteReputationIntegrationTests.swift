//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SudoKeyManager
import SudoUser
import SudoSiteReputation

class SudoSiteReputationIntegrationTests: XCTestCase {
    func testCheckSiteReputation() throws {
        // Initialize the client.
        let namespace = "srs-integration-test"
        let userClient = try DefaultSudoUserClient(keyNamespace: namespace)
        let client = try DefaultSudoSiteReputationClient(
            userClient: userClient,
            storageNamespace: namespace
        )

        try client.clearStorage()
        try userClient.reset()

        XCTAssertFalse(userClient.isRegistered())

        try register(userClient: userClient)
        defer {
            try? deregister(userClient: userClient)
            try? userClient.reset()
            try? client.clearStorage()
        }

        try signIn(userClient: userClient)

        // Perform a check before `update` and verify that it fails.
        let check1Result = client.getSiteReputation(url: "https://sudoplatform.com")
        switch check1Result {
        case .failure(.reputationDataNotPresent): break
        default: XCTFail("check before `update` should report no data")
        }
        XCTAssertEqual(client.lastUpdatePerformedAt, nil)

        // Perform an `update`.
        let updateExpectation = expectation(description: "update")
        client.update { result in
            updateExpectation.fulfill()
            switch result {
            case .success: break
            case .failure(let error):
                XCTFail("update failed: \(error)")
            }
        }
        wait(for: [updateExpectation], timeout: 60)

        // Update a second time, just to make sure we can.
        // If this fails with alreadyInProgress, it is likely that the
        // previous update() call retained the lock on the shared Cache.
        let updateAgainExpectation = expectation(description: "update again")
        client.update { result in
            updateAgainExpectation.fulfill()
            switch result {
            case .success: break
            case .failure(let error):
                XCTFail("update failed: \(error)")
            }
        }
        wait(for: [updateAgainExpectation], timeout: 60)

        // Verify that `lastUpdatePerformedAt` has been bumped.
        XCTAssertEqual(
            client.lastUpdatePerformedAt?.timeIntervalSince1970 ?? 0,
            Date().timeIntervalSince1970, accuracy: 5)

        // Check that known non-malicious sites have good reputation.
        let check = { (url: String, expectedMalicious: Bool) in
            let reputation = try client.getSiteReputation(url: url).get()
            XCTAssertEqual(reputation.isMalicious, expectedMalicious)
        }
        try check("https://docs.sudoplatform.com/guides/getting-started", false)
        try check("anonyome.com", false)

        // NOTE: These tests rely on the environment we are using to have set up
        // the site reputation service with a test malicious domain list.
        // If these checks fail, the Site Reputation Service may not be set up.
        let siteReputationServiceIsConfigured = false
        if siteReputationServiceIsConfigured {
            try check("192.0.2.42", true)
            try check("https://subdomain.evil-site.example/some/path.php", true)
        }
    }

    private func register(userClient: SudoUserClient) throws {
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

        let shouldRegister = expectation(description: "register should complete")
        var registerResult: Result<String, Error>!
        try userClient.registerWithAuthenticationProvider(
            authenticationProvider: TESTAuthenticationProvider(
                name: "testRegisterAudience",
                key: testKey,
                keyId: testKeyId,
                keyManager: SudoKeyManagerImpl(
                    serviceName: "com.sudoplatform.appservicename",
                    keyTag: "com.sudoplatform",
                    namespace: "test"
                )
            ),
            registrationId: "srs-int-test-\(Date())"
        ) { result in
            shouldRegister.fulfill()
            registerResult = result
        }
        wait(for: [shouldRegister], timeout: 120)

        _ = try registerResult.get()
    }

    private func signIn(userClient: SudoUserClient) throws {
        let shouldSignIn = expectation(description: "signIn should complete")
        var signInResult: Result<AuthenticationTokens, Error>!
        try userClient.signInWithKey { result in
            shouldSignIn.fulfill()
            signInResult = result
        }
        wait(for: [shouldSignIn], timeout: 120)
        _ = try signInResult.get()
    }

    private func deregister(userClient: SudoUserClient) throws {
        let shouldDeregister = expectation(description: "deregister")
        try userClient.deregister { result in
            shouldDeregister.fulfill()
            switch result {
            case .success: break
            case .failure(let error):
                print("warning: Failed to deregister: \(error)")
            }
        }
        wait(for: [shouldDeregister], timeout: 120)
    }
}
