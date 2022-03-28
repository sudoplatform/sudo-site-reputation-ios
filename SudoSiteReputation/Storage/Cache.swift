//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// An interface to a persistent cache of malicious domain lists.
protocol CacheAccessor {
    /// Places a malicious domain list in the cache.
    /// - Parameter list: List to store.
    /// - Returns: Success or an error from persistent storage.
    func put(list: MaliciousDomainList) -> Result<Void, CacheAccessError>

    /// Retrieves a single malicious domain list from the cache.
    /// - Parameter key: Key identifying the malicious domain list.
    /// - Returns: The list, or nil if not in the cache, or an error from persistent storage.
    func get(key: MaliciousDomainListKey) -> Result<MaliciousDomainList?, CacheAccessError>

    /// Retrieves all malicious domain lists from the cache.
    /// - Returns: The lists or an error from persistent storage.
    func get() -> Result<[MaliciousDomainList], CacheAccessError>

    /// Clears all contents in persistent storage.
    /// - Returns: Success or an error from persistent storage.
    /// The caller should inspect the error to determine if a retry is warranted.
    func reset() -> Result<Void, CacheAccessError>

    /// A value managed by the user of the cache which tracks the timestamp of cache contents.
    var lastUpdatePerformedAt: Date? { get set }
}

/// An error raised by a `CacheAccessor`.
enum CacheAccessError: Error {
    /// An error occurred when accessing the persistent storage.
    case storageError(_ underlyingError: Error)

    /// An error occurred when encoding or decoding cached data.
    case codableError(_ underlyingError: Error)
}

/// Provides synchronized access to a `CacheAccessor` in order to
/// prevent data races when modifying the underlying persistent storage.
class Cache {
    private let lock = NSLock()
    private let accessor: CacheAccessor

    /// Instantiates a `Cache` backed by the provided accessor.
    /// - Parameter accessor: Backing accessor.
    init(accessor: CacheAccessor) {
        self.accessor = accessor
    }

    /// Maintains exclusive access to the underlying `impl` until the token `deinit` occurs.
    private class CacheToken: CacheAccessor {
        private var impl: CacheAccessor
        private let unlock: () -> Void

        init(impl: CacheAccessor, unlock: @escaping () -> Void) {
            self.impl = impl
            self.unlock = unlock
        }

        deinit { self.unlock() }

        func put(list: MaliciousDomainList) -> Result<Void, CacheAccessError> {
            return impl.put(list: list)
        }

        func get(key: MaliciousDomainListKey) -> Result<MaliciousDomainList?, CacheAccessError> {
            return impl.get(key: key)
        }

        func get() -> Result<[MaliciousDomainList], CacheAccessError> {
            return impl.get()
        }

        func reset() -> Result<Void, CacheAccessError> {
            return impl.reset()
        }

        var lastUpdatePerformedAt: Date? {
            get { return impl.lastUpdatePerformedAt }
            set { impl.lastUpdatePerformedAt = newValue }
        }
    }

    /// Attempts to acquire exclusive access to the cache in a non-blocking fashion.
    /// - Returns: Exclusive access to the cache or `nil` if the accessor could not be acquired.
    func tryAccess() -> CacheAccessor? {
        guard lock.try() else { return nil }
        return CacheToken(impl: accessor) { self.lock.unlock() }
    }

    /// Exclusive access to the cache could not be obtained within the timeout period.
    struct CacheAccessTimeoutError: Error {}

    /// Blocks until exclusive access to the cache is obtained.
    /// - Throws: `CacheAccessTimeoutError` if acquisition times out.
    /// - Returns: Exclusive access to the cache.
    func access() throws -> CacheAccessor {
        guard lock.lock(before: Date().addingTimeInterval(2)) else {
            throw CacheAccessTimeoutError()
        }
        return CacheToken(impl: accessor) { self.lock.unlock() }
    }

    /// Returns the `lastUpdatePerformedAt` property of the backing accessor.
    /// Unsynchronized under the assumption that reading the corresponding accessor property is atomic.
    var lastUpdatePerformedAt: Date? {
        return accessor.lastUpdatePerformedAt
    }
}

/// An implementation of `CacheAccessor` that stores malicious domain lists in-memory.
class InMemoryCacheAccessor: CacheAccessor {
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
}
