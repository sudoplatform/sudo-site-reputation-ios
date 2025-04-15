//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// An interface to a persistent cache of malicious domain lists.
protocol ServiceDataCache: Actor {
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

    func setLastUpdatePerformedAt(date: Date?) async
}

/// An error raised by a `ServiceDataCache`.
enum CacheAccessError: LocalizedError {
    /// An error occurred when accessing the persistent storage.
    case storageError(_ underlyingError: Error)

    /// An error occurred when encoding or decoding cached data.
    case codableError(_ underlyingError: Error)

    // MARK: - Conformance: LocalizedError

    public var errorDescription: String? {
        switch self {
        case .storageError(let underlyingError):
            return L10n.SiteReputation.Errors.CacheAccessError.storageError(underlyingError.localizedDescription)
        case .codableError(let underlyingError):
            return L10n.SiteReputation.Errors.CacheAccessError.codableError(underlyingError.localizedDescription)
        }
    }
}

/// An implementation of `ServiceDataCache` that stores malicious domain lists to disk.
actor DiskServiceDataCache: ServiceDataCache {

    // MARK: - Properties

    var fileManager: FileManager = .default
    let directory: URL

    // MARK: - Lifecycle

    /// Instantiates a `DiskCacheAccessor`.
    /// - Parameter directory: Directory the accessor will read and write to.
    init(directory: URL) {
        self.directory = directory
    }

    // MARK: - Conformance: ServiceDataCache

    func put(list: MaliciousDomainList) -> Result<Void, CacheAccessError> {
        return Result { try JSONEncoder().encode(list) }
        .mapError(CacheAccessError.codableError)
        .flatMap { data in Result {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: directory.appendingPathComponent(list.slug))
        }.mapError(CacheAccessError.storageError) }
    }

    func get(key: MaliciousDomainListKey) -> Result<MaliciousDomainList?, CacheAccessError> {
        let data: Data
        do {
            data = try Data(contentsOf: directory.appendingPathComponent(key.slug))
        } catch CocoaError.fileNoSuchFile, CocoaError.fileReadNoSuchFile {
            return .success(nil)
        } catch let error {
            return .failure(.storageError(error))
        }

        do {
            return .success(try JSONDecoder().decode(MaliciousDomainList.self, from: data))
        } catch let error {
            return .failure(.codableError(error))
        }
    }

    func get() -> Result<[MaliciousDomainList], CacheAccessError> {
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: []
            )
        } catch CocoaError.fileNoSuchFile, CocoaError.fileReadNoSuchFile {
            return .success([])
        } catch let error {
            return .failure(.storageError(error))
        }

        let parsedLists = contents.map { path -> Result<MaliciousDomainList, CacheAccessError> in
            let data: Data
            do {
                data = try Data(contentsOf: path)
            } catch let error {
                return .failure(.storageError(error))
            }

            let list: MaliciousDomainList
            do {
                list = try JSONDecoder().decode(MaliciousDomainList.self, from: data)
            } catch let error {
                return .failure(.codableError(error))
            }

            return .success(list)
        }

        // extract the result of each
        let maliciousDomainLists = parsedLists.compactMap {
            return $0.value
        }

        let parseErrors: [CacheAccessError] = parsedLists.compactMap {
            return $0.error
        }

        // Only consider fetching lists a failure if there was an error and no other lists were successfully parsed.
        // swiftlint:disable empty_count
        if let firstParseError = parseErrors.first, maliciousDomainLists.count == 0 {
            return .failure(firstParseError)
        } else {
            return .success(maliciousDomainLists)
        }
    }

    func reset() -> Result<Void, CacheAccessError> {
        return Result(catching: {
            do {
                try fileManager.removeItem(at: directory)
            } catch CocoaError.fileNoSuchFile, CocoaError.fileReadNoSuchFile {
                // Ignore error if directory does not exist.
            }
        })
            .mapError(CacheAccessError.storageError)
    }

    private var lastUpdateFile: URL {
        return directory.appendingPathComponent("last-updated.txt")
    }

    var lastUpdatePerformedAt: Date? {
        get {
            return (try? String(contentsOf: lastUpdateFile))
                .flatMap(TimeInterval.init)
                .map(Date.init(timeIntervalSince1970:))
        }
        set {
            if let newValue = newValue {
                try? fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                try? String(Int(newValue.timeIntervalSince1970)).write(
                    to: lastUpdateFile,
                    atomically: true,
                    encoding: .utf8
                )
            } else {
                try? fileManager.removeItem(at: lastUpdateFile)
            }
        }
    }

    func setLastUpdatePerformedAt(date: Date?) async {
        self.lastUpdatePerformedAt = date
    }
}

extension Result {

    /// Will return the associated success value from the instance if it is the `success` case
    var value: Success? {
        return try? self.get()
    }

    /// Will return the associated error if the instance is the `failed` case
    var error: Failure? {
        switch self {
        case .failure(let output):
            return output
        case .success:
            return nil
        }
    }
}
