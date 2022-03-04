//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AWSS3
@testable import SudoSiteReputation
import Foundation

extension String: Error {}

class MockS3Client: S3Client {
    
    var mockKeys: [String] = []
    var mockMoreData: Bool = false
    var mockBodies: [String] = []

    var listObjectsV2Called: Int = 0
    var listObjectsV2Request: AWSS3ListObjectsV2Request?
    func listObjectsV2(_ request: AWSS3ListObjectsV2Request) async throws -> AWSS3ListObjectsV2Output? {
        listObjectsV2Called += 1
        return makeListOutput(keys: mockKeys, moreData: mockMoreData)
    }

    var getObjectCalled: Int = 0
    var getObjectRequest: AWSS3GetObjectRequest?
    func getObject(_ request: AWSS3GetObjectRequest) async throws -> AWSS3GetObjectOutput? {
        getObjectCalled += 1

        // Get the index of the key
        guard let key = request.key, let keyIndex = mockKeys.firstIndex(of: key) else {
            let details = "'\(request.bucket ?? "")', '\(request.key ?? "")'"
            throw "Unexpected bucket/key passed to getObject: \(details)"
        }

        // Set the result by using the body associated with the key.
        return makeGetOutput(body: mockBodies[keyIndex])
    }

    // MARK: - Helpers
    func makeListOutput(keys: [String],
                        moreData: Bool = false) -> AWSS3ListObjectsV2Output {
        let output = AWSS3ListObjectsV2Output()!
        output.contents = keys.map { key in
            let object = AWSS3Object()!
            object.key = key
            object.eTag = "unit-test"
            object.lastModified = Date()
            return object
        }
        output.nextContinuationToken = moreData ? "unit-test-token" : nil
        return output
    }

    func makeGetOutput(body: String) -> AWSS3GetObjectOutput {
        let output = AWSS3GetObjectOutput()!
        output.body = Data(body.utf8)
        output.eTag = "unit-test"
        output.lastModified = Date()
        output.metadata = [
            "sudoplatformblob": """
{
  "name.en": "Unit Test Sample",
  "categoryEnum": "MALICIOUSDOMAIN"
}
"""
        ]
        return output
    }
}
