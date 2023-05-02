//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AWSAppSync
import AWSCore
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
    // App sync client used to interact with the remote service via graphQL
    let appSyncClient: SudoApiClient
    
    init(appSyncClient: SudoApiClient) {
        self.appSyncClient = appSyncClient
    }

    /// Create a new client using the shared SudoAPIClient instance
    convenience init(userClient: SudoUserClient) throws {
        guard let client = try SudoApiClientManager.instance?.getClient(sudoUserClient: userClient) else {
            throw InvalidDependencyError()
        }
        self.init(appSyncClient: client)
    }
    
    let reputationCache = ExpensiveObjectCache<GraphQL.GetSiteReputationQuery.Data>()

    func getReputation(url: String) async throws -> GraphQL.GetSiteReputationQuery.Data {
        return try await reputationCache.get(key: url) {
            let query = GraphQL.GetSiteReputationQuery(uri: url)
            let result = try await self.appSyncClient.fetch(query: query, cachePolicy: .fetchIgnoringCacheData, queue: .global(qos: .userInitiated))
            
            if let error = result.error {
                throw error
            }
            
            if let graphQLErrors = result.result?.errors {
                throw PlatformGraphQLError(errors: graphQLErrors)
            }
            
            guard let data = result.result?.data else {
                throw MissingResponseDataError()
            }
            
            return data
        }
    }
    
    func reset() async {
        await reputationCache.reset()
    }
}

