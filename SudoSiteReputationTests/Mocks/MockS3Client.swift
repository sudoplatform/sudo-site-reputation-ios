//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AWSS3
@testable import SudoSiteReputation

class MockS3Client: S3Client {
    typealias ListObjectsV2 = (_ request: AWSS3ListObjectsV2Request, _ completionHandler: ((AWSS3ListObjectsV2Output?, Error?) -> Void)?) -> Void
    typealias GetObject = (_ request: AWSS3GetObjectRequest, _ completionHandler: ((AWSS3GetObjectOutput?, Error?) -> Void)?) -> Void

    var _listObjectsV2: ListObjectsV2!
    var _getObject: GetObject!

    func listObjectsV2(_ request: AWSS3ListObjectsV2Request, completionHandler: ((AWSS3ListObjectsV2Output?, Error?) -> Void)?) {
        return self._listObjectsV2(request, completionHandler)
    }

    func getObject(_ request: AWSS3GetObjectRequest, completionHandler: ((AWSS3GetObjectOutput?, Error?) -> Void)?) {
        return self._getObject(request, completionHandler)
    }

    // MARK: - Helpers

    static func makeListOutput(
        keys: [String],
        moreData: Bool = false
    ) -> AWSS3ListObjectsV2Output {
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

    static func makeGetOutput(body: String) -> AWSS3GetObjectOutput {
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
