//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
@testable import SudoSiteReputation

/// An implementation of `ServiceDataCache` that stores malicious domain lists in-memory.
final actor InMemoryServiceDataCache: ServiceDataCache {

    /// Malicious domain lists maintained by the cache.
    internal private(set) var lists: [String: MaliciousDomainList] = [:]

    var lastUpdatePerformedAt: Date?

    func put(list: MaliciousDomainList) -> Result<Void, CacheAccessError> {
        lists[list.key] = list
        return .success(())
    }

    func get(key: MaliciousDomainListKey) -> Result<MaliciousDomainList?, CacheAccessError> {
        return .success(lists[key.key])
    }

    func get() -> Result<[MaliciousDomainList], CacheAccessError> {
        return .success(Array(lists.values))
    }

    func reset() -> Result<Void, CacheAccessError> {
        lists = [:]
        lastUpdatePerformedAt = nil
        return .success(())
    }

    func setLastUpdatePerformedAt(date: Date?) async {
        self.lastUpdatePerformedAt = date
    }
}

final actor MockServiceDataCache: ServiceDataCache {
    var putResult: Result<Void, CacheAccessError>! = .failure(.storageError("nil"))
    func setPutResult(result: Result<Void, CacheAccessError>) {
        putResult = result
    }
    func put(list: MaliciousDomainList) -> Result<Void, CacheAccessError> {
        return putResult
    }

    var getResult: Result<MaliciousDomainList?, CacheAccessError>! = .failure(.storageError("nil"))
    func setGetResult(result: Result<MaliciousDomainList?, CacheAccessError>) {
        getResult = result
    }
    func get(key: MaliciousDomainListKey) -> Result<MaliciousDomainList?, CacheAccessError> {
        return getResult
    }

    var getAllResult: Result<[MaliciousDomainList], CacheAccessError>! = .failure(.storageError("nil"))
    func setGetAllResult(result: Result<[MaliciousDomainList], CacheAccessError>) {
        getAllResult = result
    }
    func get() -> Result<[MaliciousDomainList], CacheAccessError> {
        return getAllResult
    }

    var resetResult: Result<Void, CacheAccessError>! = .failure(.storageError("nil"))
    func setResetResult(result: Result<Void, CacheAccessError>) {
        resetResult = result
    }
    func reset() -> Result<Void, CacheAccessError> {
        return resetResult
    }

    var lastUpdatePerformedAt: Date?

    func setLastUpdatePerformedAt(date: Date?) async {
        self.lastUpdatePerformedAt = date
    }
}
