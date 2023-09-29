//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

import XCTest
import SudoKeyManager
import SudoUser
import SudoEntitlements
import SudoEntitlementsAdmin
@testable import SudoSiteReputation

/// Allows a string to be an error for test purposes and makes it simpler to say "something isn't right".
extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

/// Base integration test that handles setup, registration, and degregistration of sudo user so
/// integration tests that require authentication can run.
class IntegrationTestBase: XCTestCase {

    var userClient: SudoUserClient!
    var sudoEntitlementsClient: SudoEntitlementsClient!
    
    override func setUp() async throws {
        // Initialize the client.
        let namespace = "srs-integration-test"
        self.userClient = try DefaultSudoUserClient(keyNamespace: namespace)
        try await userClient.reset()
        
        let isRegistered = try await userClient.isRegistered()
        XCTAssertFalse(isRegistered)
        
        try await register(userClient: userClient)
        try await signIn(userClient: userClient)
        
        try await entitle()
        
        let sudoEntitlementsClient = try DefaultSudoEntitlementsClient(userClient: userClient)
        try sudoEntitlementsClient.reset()
        _ = try await sudoEntitlementsClient.redeemEntitlements()
    }
    
    
    func entitle() async throws {
        guard let apiKey = readKeys()?.apiKey else {
            throw "failed to read api entitlements key"
        }
        
        let sudoEntitlementsAdminClient = try DefaultSudoEntitlementsAdminClient(apiKey: apiKey)
        
        guard let username = try userClient.getUserName() else {
            throw "failed to get username"
        }

        _ = try await sudoEntitlementsAdminClient.applyEntitlementsToUserWithExternalId(
            username,
            entitlements: [
                Entitlement(name: "sudoplatform.sr.srUserEntitled", description: "", value: 1),
            ]
        )
    }
    
    func loadFile(name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else {
            return nil
        }
        return try? String(contentsOf: url)
    }
    
    func readKeys() -> (apiKey: String, testKey: String, testKeyId: String)? {
        // exported ENV variables from the shell are setup by modifying the scheme.
        guard let apiKey = (loadFile(name: "api.key") ?? ProcessInfo.processInfo.environment["ADMIN_API_KEY"]) else {
            XCTFail("API_KEY environment variable not set or api.key file not found.")
            return nil
        }
        
        guard let testKey = loadFile(name: "register_key.private") ?? ProcessInfo.processInfo.environment["REGISTER_KEY"] else {
            XCTFail("REGISTER_KEY environment variable not set or register_key.private file not found.")
            return nil
        }

        guard let testKeyId = loadFile(name: "register_key.id") else {
            XCTFail("Failed to read TEST key ID from file: register_key.id")
            return nil
        }
        
        return (apiKey.trimmingCharacters(in: .whitespacesAndNewlines), testKey, testKeyId)
    }
    
    
    override func tearDown() async throws {
        try await deregister(userClient: userClient)
        try await userClient.reset()
    }

    private func register(userClient: SudoUserClient) async throws {
        guard let keys = readKeys() else {
            let message = "Missing register_key.private or register_key.id. Please make sure these files are present in ${PROJECT_DIR}/config and are copied to the testing bundle."
            throw message
        }

        let keyManager = LegacySudoKeyManager(serviceName: "com.sudoplatform.appservicename",
                                              keyTag: "com.sudoplatform",
                                              namespace: "test")
        let authProvider = try TESTAuthenticationProvider(name: "testRegisterAudience",
                                                          key: keys.testKey,
                                                          keyId: keys.testKeyId,
                                                          keyManager: keyManager)
        _ = try await userClient.registerWithAuthenticationProvider(authenticationProvider: authProvider,
                                                                    registrationId: "srs-int-test-\(Date())")
    }

    // TODO: This doesn't make sense to catch and print the failure.
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

