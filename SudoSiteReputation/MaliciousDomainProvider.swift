//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SudoLogging
import AWSCore

protocol MaliciousDomainListProviding {
    func fetchMaliciousDomainLists() async -> [MaliciousDomainList]?
    func update() async throws
    func clearStorage() async throws
    func lastUpdatePerformedAt() async -> Date?
}

class MaliciousDomainListProvider: MaliciousDomainListProviding {

    let staticDataBucket: String
    var s3: S3Client
    var cache: ServiceDataCache
    var cancelInProgressUpdate: (() -> Void)?
    var logger: Logger

    internal init(
        staticDataBucket: String,
        s3: S3Client,
        cache: ServiceDataCache,
        logger: Logger
    ) {
        self.staticDataBucket = staticDataBucket
        self.s3 = s3
        self.cache = cache
        self.logger = logger
    }

    /// Moved from client.  Consults the cache for list data.
    /// - Returns: Lists cached on disk. Nil if no lists were found.
    func fetchMaliciousDomainLists() async -> [MaliciousDomainList]? {
        do {
            let lists = try await cache.get().get()

            // It is more likely that an empty cache signifies "data not present"
            // than "service contains no lists", so flag data as not present then.
            guard !lists.isEmpty else {
                return nil
            }

            return lists
        } catch {
            logger.error("Failed to read cached lists: \(error.localizedDescription)")
            return nil
        }
    }

    func lastUpdatePerformedAt() async -> Date? {
        return await cache.lastUpdatePerformedAt
    }

    var inProgressUpdateTask: Task<(), Error>?
    // Moved from client.  Fetches lists and list data from the service.
    // Data is cached and referenced before downloading list data if it hasn't changed.
    func update() async throws {
        let s3 = self.s3
        let logger = self.logger
        let bucket = self.staticDataBucket

        let updateTask = Task {
            // Get all keys in cache
            let keys = try await listMaliciousDomainListKeys(s3: s3, logger: logger, bucket: bucket)

            try Task.checkCancellation()

            // Check if any need to be updated
            var keysNeedingFetch: [MaliciousDomainListKey] = []
            for key in keys {
                if let cachedList = try? await self.cache.get(key: key).get() {
                    if key.eTag != cachedList.eTag {
                        keysNeedingFetch.append(key)
                    }
                } else {
                    keysNeedingFetch.append(key)
                }
            }

            try Task.checkCancellation()

            // Download needed keys
            var downloads: [MaliciousDomainList] = []
            await withTaskGroup(of: MaliciousDomainList?.self) { group in
                for key in keysNeedingFetch {
                    group.addTask(priority: nil) {
                        do {
                            async let list = fetchMaliciousDomainList(s3: s3, logger: logger, key: key)
                            return try await list
                        } catch {
                            // log error of download failure.
                            return nil
                        }
                    }
                }

                for await download in group {
                    if let download = download {
                        downloads.append(download)
                    }
                }

                // Put the new keys in the cache.
                guard !Task.isCancelled else { return }
                for download in downloads {
                    _ = await cache.put(list: download)
                }
            }
        }

        self.inProgressUpdateTask = updateTask

        do {
            try await updateTask.value
            self.inProgressUpdateTask = nil
        } catch {
            self.inProgressUpdateTask = nil
            throw error
        }
        await cache.setLastUpdatePerformedAt(date: Date())
    }

    func clearStorage() async throws {

        self.inProgressUpdateTask?.cancel()
        // Cancel an in-progress update call in order to release the cache.
        self.cancelInProgressUpdate?()
        self.cancelInProgressUpdate = nil

        // Block until we can access the cache to clear persistent storage.
        try await self.cache.reset().get()
    }
}
