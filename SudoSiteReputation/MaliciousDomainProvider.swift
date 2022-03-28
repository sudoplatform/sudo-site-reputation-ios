//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoLogging
import AWSCore

protocol MaliciousDomainListProviding {
    func fetchMaliciousDomainLists() -> [MaliciousDomainList]?
    func update(completion: @escaping (Result<[MaliciousDomainList], SiteReputationUpdateError>) -> Void)
    func clearStorage() throws
    var lastUpdatePerformedAt: Date? { get }
}

class MaliciousDomainListProvider: MaliciousDomainListProviding {

    private let staticDataBucket: String
    private let s3: S3Client
    private let cache: Cache
    private var cancelInProgressUpdate: (() -> Void)?
    var logger: Logger

    internal init(
        staticDataBucket: String,
        s3: S3Client,
        cache: Cache,
        logger: Logger
    ) {
        self.staticDataBucket = staticDataBucket
        self.s3 = s3
        self.cache = cache
        self.logger = logger
    }

    /// Moved from client.  Consults the cache for list data.
    /// - Returns: Lists cached on disk. Nil if no lists were found.
    func fetchMaliciousDomainLists() -> [MaliciousDomainList]? {
        // Since this is only called from init we expect `access` to succeed.
        // Otherwise rely on the user calling `update` before trying to check.
        guard let cache = self.cache.tryAccess() else {
            return nil
        }

        let lists: [MaliciousDomainList]
        switch cache.get() {
        case .success(let cachedLists):
            lists = cachedLists
        case .failure(let error):
            logger.error("Failed to read cached lists: \(error.localizedDescription)")
            return nil
        }

        // It is more likely that an empty cache signifies "data not present"
        // than "service contains no lists", so flag data as not present then.
        guard !lists.isEmpty else {
            return nil
        }

        return lists
    }

    var lastUpdatePerformedAt: Date? {
        return cache.lastUpdatePerformedAt
    }

    // Moved from client.  Fetches lists and list data from the service.
    // Data is cached and referenced before downloading list data if it hasn't changed.
    /// - Returns: Lists or an error.
    func update(completion: @escaping (Result<[MaliciousDomainList], SiteReputationUpdateError>) -> Void) {
        var cacheRef = self.cache.tryAccess()
        guard cacheRef != nil else {
            // If an update or reset is already in progress, do nothing.
            return completion(.failure(.alreadyInProgress))
        }

        // Allow cancelling an in-progress update and releasing the cache ref.
        // This assignment is safe since we hold the cache lock.
        // NOTE: This closure must be released before calling completion.
        self.cancelInProgressUpdate = { cacheRef = nil }

        let s3 = self.s3
        let logger = self.logger
        let bucket = self.staticDataBucket

        listMaliciousDomainListKeys(s3: s3, logger: logger, bucket: bucket) { result in
            switch result {
            case .success(let keys):
                let queue = DispatchQueue(label: "com.sudoplatform.sitereputation.update")
                let dispatchGroup = DispatchGroup()
                var maliciousDomainList: [MaliciousDomainList] = []
                var failure: FetchMaliciousDomainListError?
                var cancelled = false

                keys.forEach { key in
                    // Attempt to read the old list version from the cache.
                    let existingList: MaliciousDomainList?
                    switch cacheRef?.get(key: key) {
                    case .none:
                        queue.sync { cancelled = true }
                        return
                    case .success(let list):
                        existingList = list
                    case .failure(let error):
                        logger.error("Failed to read cached list: \(error.localizedDescription)")
                        existingList = nil
                    }

                    // Skip fetching the list if the ETag matches what is cached.
                    if let existingList = existingList, key.eTag == existingList.eTag {
                        queue.sync { maliciousDomainList.append(existingList) }
                        return
                    }

                    dispatchGroup.enter()

                    fetchMaliciousDomainList(s3: s3, logger: logger, key: key) { result in
                        defer { dispatchGroup.leave() }

                        switch result {
                        case .success(let newList):
                            // Attempt to put the new list in the cache.
                            switch cacheRef?.put(list: newList) {
                            case .none:
                                queue.sync { cancelled = true }
                            case .success: break
                            case .failure(let error):
                                logger.error("Failed to update cached list: \(error.localizedDescription)")
                            }

                            // Add the new list contents to the list of domains.
                            queue.sync { maliciousDomainList.append(newList) }

                        case .failure(let error):
                            logger.error("Failed to fetch list: \(error.localizedDescription)")

                            // If the network update failed, use the existing list.
                            queue.sync {
                                if let existingList = existingList {
                                    maliciousDomainList.append(existingList)
                                }
                                failure = error
                            }
                        }
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    if cancelled {
                        return completion(.failure(.cancelled))
                    }

                    self.cancelInProgressUpdate = nil

                    if let failure = failure {
                        return completion(.failure(.serviceError(failure)))
                    } else {
                        cacheRef?.lastUpdatePerformedAt = Date()
                        return completion(.success(maliciousDomainList))
                    }
                }
            case .failure(let error):
                self.cancelInProgressUpdate = nil
                return completion(.failure(.serviceError(error)))
            }
        }
    }

    func clearStorage() throws {
        // Cancel an in-progress update call in order to release the cache.
        self.cancelInProgressUpdate?()
        self.cancelInProgressUpdate = nil

        // Block until we can access the cache to clear persistent storage.
        try self.cache.access().reset().get()
    }
}
