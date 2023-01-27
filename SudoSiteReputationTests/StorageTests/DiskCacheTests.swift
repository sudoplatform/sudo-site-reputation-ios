//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import Foundation
@testable import SudoSiteReputation

class DiskCacheTests: XCTestCase {
    var fileManager: FileManager!
    var directory: URL!
    var cache: DiskServiceDataCache!

    let list = MaliciousDomainList(
        key: "/site-reputation/reputation-lists/MALICIOUSDOMAIN/unit-test.txt",
        eTag: "etag-unit-test",
        category: "MALICIOUSDOMAIN",
        name: "Unit Test Sample List",
        body: Data("hello-world.example".utf8)
    )
    var key: MaliciousDomainListKey {
        return .init(key: list.key, bucket: "unit-test", eTag: list.eTag)
    }

    override func setUpWithError() throws {
        fileManager = .default
        directory = fileManager.temporaryDirectory.appendingPathComponent("unit-test")
        cache = DiskServiceDataCache(fileManager: fileManager, directory: directory)

        try cleanUpDirectory()
    }

    override func tearDownWithError() throws {
        try cleanUpDirectory()
    }

    func cleanUpDirectory() throws {
        do {
            try fileManager.setAttributes(
                [.posixPermissions: 0o777],
                ofItemAtPath: directory.path
            )
            try fileManager.removeItem(at: directory)
        } catch CocoaError.fileNoSuchFile, CocoaError.fileReadNoSuchFile {
            // This is fine.
        }
    }

    func testPutGet() async throws {
        // Use the cache to store a list.
        let put = await cache.put(list: list)
        XCTAssertNoThrow(try put.get())

        // Verify that the list was persisted to the disk.
        let expectedPath = directory.appendingPathComponent("unit-test.txt")
        XCTAssertTrue(fileManager.isReadableFile(atPath: expectedPath.path))

        // Verify that the list can now be read from the cache by key.
        let get = try await cache.get(key: key).get()
        XCTAssertEqual(get, list)

        // Verify that the list is also present when listing all cache entries.
        let getContainsList = try await cache.get().get().contains(list)
        XCTAssertTrue(getContainsList)
    }

    func testPutError() async throws {
        // Create the directory as read-only.
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o444]
        )

        // Call put. Verify that it fails as expected.
        switch await cache.put(list: list) {
        case .failure(.storageError): break
        default: XCTFail("expected failure to modify directory")
        }
    }

    func testGetNil() async throws {
        // Call get without populating the cache and verify nil is returned.
        switch await cache.get(key: key) {
        case .success(.none): break
        default: XCTFail("expected nil cache result")
        }
    }

    func testGetError() async throws {
        // Initialize the cache with inaccessible mock data.
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        fileManager.createFile(
            atPath: directory.appendingPathComponent("unit-test.txt").path,
            contents: Data("hello".utf8),
            attributes: [.posixPermissions: 0o222]
        )

        // Call get. Verify that it fails as expected.
        switch await cache.get(key: key) {
        case .failure(.storageError): break
        default: XCTFail("expected failure to access file")
        }
    }

    func testGetAllEmpty() async throws {
        // Call get. Verify that it returns an empty list.
        switch await cache.get() {
        case .success([]): break
        default: XCTFail("expected empty list")
        }
    }

    func testGetAllError() async throws {
        // Create the directory as inaccessible.
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o000]
        )

        // Call get. Verify that it fails as expected.
        switch await cache.get() {
        case .failure(.storageError): break
        default: XCTFail("expected failure to access directory")
        }
    }

    func testReset() async throws {
        // Initialize the cache with mock data.
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o770]
        )
        try Data("unit test".utf8)
            .write(to: directory.appendingPathComponent("unit-test.txt"))

        // Call reset.
        try await cache.reset().get()

        // Verify that the cache directory is now empty.
        let path = directory.path
        XCTAssertTrue(
            try !fileManager.fileExists(atPath: path)
                || fileManager.contentsOfDirectory(atPath: path).isEmpty)
    }

    func testResetError() async throws {
        // Create the directory as inaccessible.
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o000]
        )

        // Call reset. Verify that it fails as expected.
        switch await cache.reset() {
        case .failure(.storageError): break
        default: XCTFail("expected failure to modify directory")
        }
    }

    func testLastUpdatePerformedAt() async throws {
        let date1 = Date().addingTimeInterval(-60 * 60 * 24)
        await cache.setLastUpdatePerformedAt(date: date1)
        let cacheDate1 = await cache.lastUpdatePerformedAt?.timeIntervalSince1970 ?? 0
        XCTAssertEqual(cacheDate1, date1.timeIntervalSince1970, accuracy: 1)

        let date2 = Date()
        await cache.setLastUpdatePerformedAt(date: date2)
        let cacheDate2 = await cache.lastUpdatePerformedAt?.timeIntervalSince1970 ?? 0
        XCTAssertEqual(cacheDate2, date2.timeIntervalSince1970, accuracy: 1)

        await cache.setLastUpdatePerformedAt(date: nil)
        let cacheDate3 = await cache.lastUpdatePerformedAt
        XCTAssertEqual(cacheDate3, nil)

        await cache.setLastUpdatePerformedAt(date: date1)
        XCTAssertEqual(cacheDate1, date1.timeIntervalSince1970, accuracy: 1)

        try await cache.reset().get()
        let cacheDate4 = await cache.lastUpdatePerformedAt
        XCTAssertEqual(cacheDate4, nil)
    }
}
