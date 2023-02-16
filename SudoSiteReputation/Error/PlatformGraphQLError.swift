//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSAppSync

/// A wrapper around an array of graphQL errors returned by the platform service.
public struct PlatformGraphQLError: Error {
    public let errors: [GraphQLError]
}
