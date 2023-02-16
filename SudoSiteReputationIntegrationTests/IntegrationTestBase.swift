//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

import XCTest
import SudoKeyManager
import SudoUser
@testable import SudoSiteReputation

/// Base integration test that handles setup, registration, and degregistration of sudo user so
/// integration tests that require authentication can run.
class IntegrationTestBase: XCTestCase {

    var userClient: SudoUserClient!

    override func setUpWithError() throws {
        // Initialize the client.
        let namespace = "srs-integration-test"
        self.userClient = try DefaultSudoUserClient(keyNamespace: namespace)

        let setupExpectation = self.expectation(description: "wait for setup")
        Task {
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
            tearDownExpectation.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
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
