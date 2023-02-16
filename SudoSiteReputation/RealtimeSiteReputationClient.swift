//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoUser
import SudoConfigManager

public class RealtimeSiteReputationClient {

    // API client for communicating with the site reputation service backend.
    private let apiClient: APIClient

    // init with an api client. for testing.
    internal init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public init(
        userClient: SudoUserClient
    ) throws {
        self.apiClient = try PlatformAPIClient(userClient: userClient)
    }

    public func getSiteReputation(url: String) async throws -> RealtimeReputation {
        let reputation = try await apiClient.getReputation(url: url)
        let snapshot = reputation.getSiteReputation.snapshot
        return RealtimeReputation(graphQL: GraphQL.Reputation(snapshot: snapshot))
    }
}
