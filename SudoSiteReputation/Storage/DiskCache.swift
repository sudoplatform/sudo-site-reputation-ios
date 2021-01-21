//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// An implementation of `CacheAccessor` that stores malicious domain lists to disk.
class DiskCacheAccessor: CacheAccessor {
    private let fileManager: FileManager
    private let directory: URL

    /// Instantiates a `DiskCacheAccessor`.
    /// - Parameter fileManager: File manager.
    /// - Parameter directory: Directory the accessor will read and write to.
    init(fileManager: FileManager, directory: URL) {
        self.fileManager = fileManager
        self.directory = directory
    }

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

        return contents.map { path -> Result<MaliciousDomainList, CacheAccessError> in
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
        }.reduce(.success([])) { acc, cur in
            acc.flatMap { accs in cur.map { curr in accs + [curr] } }
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
}
