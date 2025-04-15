//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import Foundation
import SudoApiClient
import SudoConfigManager
import SudoLogging
import SudoUser

protocol APIClient {
    /// Fetch the reputation for the provided url. Returns the reputation if found, otherwise nil.
    func getReputation(url: String) async throws -> GraphQL.GetSiteReputationQuery.Data
    func reset() async
}

/// Default implementation of APIClient which speaks to the platform site reputation service..
class PlatformAPIClient: APIClient {

    // MARK: - Properties

    /// App sync client used to interact with the remote service via graphQL
    let appSyncClient: SudoApiClient

    let reputationCache = ExpensiveObjectCache<GraphQL.GetSiteReputationQuery.Data>()

    // MARK: - Lifecycle

    init(appSyncClient: SudoApiClient) {
        self.appSyncClient = appSyncClient
    }

    /// Create a new client using the shared SudoAPIClient instance
    convenience init(userClient: SudoUserClient) throws {
        guard let client = try SudoApiClientManager.instance?.getClient(sudoUserClient: userClient) else {
            throw SudoSiteReputationError.invalidConfig
        }
        self.init(appSyncClient: client)
    }

    // MARK: - Conformance: APIClient

    func getReputation(url: String) async throws -> GraphQL.GetSiteReputationQuery.Data {
        return try await reputationCache.get(key: url) { [weak self] in
            guard let self else {
                throw SudoSiteReputationError.internalError("Instance deallocated")
            }
            let query = GraphQL.GetSiteReputationQuery(uri: url)
            do {
                return try await self.appSyncClient.fetch(query: query)
            } catch {
                throw SudoSiteReputationError.fromApiOperationError(error: error)
            }
        }
    }
    
    func reset() async {
        await reputationCache.reset()
    }
}

