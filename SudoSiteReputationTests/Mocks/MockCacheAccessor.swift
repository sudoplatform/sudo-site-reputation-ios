//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
@testable import SudoSiteReputation

final class MockCacheAccessor: CacheAccessor {
    var putResult: Result<Void, CacheAccessError>!
    func put(list: MaliciousDomainList) -> Result<Void, CacheAccessError> {
        return putResult
    }

    var getResult: Result<MaliciousDomainList?, CacheAccessError>!
    func get(key: MaliciousDomainListKey) -> Result<MaliciousDomainList?, CacheAccessError> {
        return getResult
    }

    var getAllResult: Result<[MaliciousDomainList], CacheAccessError>!
    func get() -> Result<[MaliciousDomainList], CacheAccessError> {
        return getAllResult
    }

    var resetResult: Result<Void, CacheAccessError>!
    func reset() -> Result<Void, CacheAccessError> {
        return resetResult
    }

    var lastUpdatePerformedAt: Date?
}
