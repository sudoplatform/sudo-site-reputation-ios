//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
@testable import SudoApiClient
@testable import AWSAppSync
import AWSCore

// This is to help with testing graphQL calls made through the SudoAPIClient appsyc wrapper layer.
//
// There are a lot of generics wrapped up in the app sync layer which provides great type safety in code,
// but it makes mocking and testing a little more difficult. This mock uses type erasure so we can provide any
// mocked data during tests, and casts the data to the correct type when returning.
//
// Other mocking approaches used in platform projects attempt to mock graphql results in the transport layer,
// i.e. by passing a network transport into the internal `AWSAppSyncClient` and then mocking results by returning the
// expected json payload.
class SudoAPIClientMock: SudoApiClient {

    // I use this conforming object in order to create an appSyncClientConfiguration.
    struct MyServiceConfig: AWSAppSyncServiceConfigProvider {
        /// The API endpoint
        var endpoint: URL = URL(string: "http://mine.me.mine.com")!

        /// The AWS region of the API endpoint
        var region: AWSRegionType = .AFSouth1

        /// The authentication method used to access the API. If this value is `.apiKey`, then the config must also provide a value
        /// for `apiKey`
        var authType: AWSAppSyncAuthType = .apiKey

        /// If `authType` is `.apiKey`, this value must provided
        var apiKey: String? = "foobar"

        /// The prefix used to partition on-disk caches
        var clientDatabasePrefix: String? = "caches"
    }

    init() throws {
        let config = AWSAppSyncClientConfiguration(appSyncServiceConfig: MyServiceConfig(), networkTransport: NetworkTransportMock())
        let appSync = try AWSAppSyncClient(appSyncConfig: config)
        try super.init(appSyncClient: appSync)
    }

    // Record of the last query sent
    var fetchQuery: Any?

    // triggers fetch to throw
    var fetchErrorToThrow: Error?

    // on success, the result to return.
    var fetchResult: (result: MockGraphQLResult?, error: Error?)?

    override public func fetch<Query: GraphQLQuery>(
        query: Query,
        cachePolicy: CachePolicy = .returnCacheDataElseFetch,
        queue: DispatchQueue = DispatchQueue.main
    ) async throws -> (result: GraphQLResult<Query.Data>?, error: Error?) {
        self.fetchQuery = query

        // Base case, throw error if this should throw
        if let error = fetchErrorToThrow {
            throw error
        }

        // unwrap the mocked result data (if provided) and cast to the correct type
        if let mockedData = fetchResult?.result {
            let typedResultData: GraphQLResult<Query.Data> = GraphQLResult<Query.Data>(
                data: mockedData.data as? Query.Data,
                errors: mockedData.errors,
                source: .server,
                dependentKeys: mockedData.dependentKeys
            )
            return (typedResultData, fetchResult?.error)
        }
        // otherwise assume the errors were provided in the result.
        else {
            return (nil, fetchResult?.error)
        }
    }
}

/// making calls to AWSAppSync or the SudoAPIClient wrapper, result objects are returned in an object with
/// this shape, but with generic data types. This is a type erased version to make mocking simpler.
public struct MockGraphQLResult {

    /// The type erased result data, or `nil` if an error was encountered that prevented a valid response.
    public let data: Any?

    /// A list of errors, or `nil` if the operation completed without encountering any errors.
    public let errors: [GraphQLError]?

    // Not used in mocks, added for completeness
    let dependentKeys: Set<CacheKey>? =  nil

    init(data: Any?, errors: [GraphQLError]?) {
        self.data = data
        self.errors = errors
    }
}

/// This network transport is the layer at which we would mock out JSON return data to our app sync layer. Not used in tests yet because it mocks data a few layers
/// down in the app sync stack and it's nice to be able to provide stubbed data closer to the app sync client dependency layer.
class NetworkTransportMock: AWSNetworkTransport {

    var data = Data()
    var jsonObject: JSONObject?
    var error: Error?
    var responseBody: [JSONObject] = []
    var variables: [GraphQLMap] = []

    func send(data: Data, completionHandler: ((JSONObject?, Error?) -> Void)?) {
        self.data = data
        completionHandler?(self.jsonObject, self.error)
    }

    func sendSubscriptionRequest<Operation>(operation: Operation, completionHandler: @escaping (JSONObject?, Error?) -> Void) throws -> Cancellable where Operation: GraphQLOperation {
        completionHandler(self.jsonObject, self.error)
        return MyCancellable()
    }

    func send<Operation>(operation: Operation, completionHandler: @escaping (GraphQLResponse<Operation>?, Error?) -> Void) -> Cancellable where Operation: GraphQLOperation {
        if let variables = operation.variables {
            self.variables.append(variables)
        }

        let response = GraphQLResponse(operation: operation, body: self.responseBody.removeFirst())
        completionHandler(response, self.error)

        return MyCancellable()
    }

}

class MyCancellable: Cancellable {

    func cancel() {}

}
