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
    var cache: DiskCacheAccessor!

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
        cache = DiskCacheAccessor(fileManager: fileManager, directory: directory)

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

    func testPutGet() throws {
        // Use the cache to store a list.
        XCTAssertNoThrow(try cache.put(list: list).get())

        // Verify that the list was persisted to the disk.
        let expectedPath = directory.appendingPathComponent("unit-test.txt")
        XCTAssertTrue(fileManager.isReadableFile(atPath: expectedPath.path))

        // Verify that the list can now be read from the cache by key.
        XCTAssertEqual(try cache.get(key: key).get(), list)

        // Verify that the list is also present when listing all cache entries.
        XCTAssertTrue(try cache.get().get().contains(list))
    }

    func testPutError() throws {
        // Create the directory as read-only.
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o444]
        )

        // Call put. Verify that it fails as expected.
        switch cache.put(list: list) {
        case .failure(.storageError): break
        default: XCTFail("expected failure to modify directory")
        }
    }

    func testGetNil() throws {
        // Call get without populating the cache and verify nil is returned.
        switch cache.get(key: key) {
        case .success(.none): break
        default: XCTFail("expected nil cache result")
        }
    }

    func testGetError() throws {
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
        switch cache.get(key: key) {
        case .failure(.storageError): break
        default: XCTFail("expected failure to access file")
        }
    }

    func testGetAllEmpty() throws {
        // Call get. Verify that it returns an empty list.
        switch cache.get() {
        case .success([]): break
        default: XCTFail("expected empty list")
        }
    }

    func testGetAllError() throws {
        // Create the directory as inaccessible.
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o000]
        )

        // Call get. Verify that it fails as expected.
        switch cache.get() {
        case .failure(.storageError): break
        default: XCTFail("expected failure to access directory")
        }
    }

    func testReset() throws {
        // Initialize the cache with mock data.
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o770]
        )
        try Data("unit test".utf8)
            .write(to: directory.appendingPathComponent("unit-test.txt"))

        // Call reset.
        try cache.reset().get()

        // Verify that the cache directory is now empty.
        let path = directory.path
        XCTAssertTrue(
            try !fileManager.fileExists(atPath: path)
                || fileManager.contentsOfDirectory(atPath: path).isEmpty)
    }

    func testResetError() throws {
        // Create the directory as inaccessible.
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o000]
        )

        // Call reset. Verify that it fails as expected.
        switch cache.reset() {
        case .failure(.storageError): break
        default: XCTFail("expected failure to modify directory")
        }
    }

    func testLastUpdatePerformedAt() throws {
        let date1 = Date().addingTimeInterval(-60 * 60 * 24)
        cache.lastUpdatePerformedAt = date1
        XCTAssertEqual(
            cache.lastUpdatePerformedAt?.timeIntervalSince1970 ?? 0,
            date1.timeIntervalSince1970,
            accuracy: 1
        )

        let date2 = Date()
        cache.lastUpdatePerformedAt = date2
        XCTAssertEqual(
            cache.lastUpdatePerformedAt?.timeIntervalSince1970 ?? 0,
            date2.timeIntervalSince1970,
            accuracy: 1
        )

        cache.lastUpdatePerformedAt = nil
        XCTAssertEqual(cache.lastUpdatePerformedAt, nil)

        cache.lastUpdatePerformedAt = date1
        XCTAssertEqual(
            cache.lastUpdatePerformedAt?.timeIntervalSince1970 ?? 0,
            date1.timeIntervalSince1970,
            accuracy: 1
        )
        try cache.reset().get()
        XCTAssertEqual(cache.lastUpdatePerformedAt, nil)
    }
}
