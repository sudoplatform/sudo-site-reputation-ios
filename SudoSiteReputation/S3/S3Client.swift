//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AWSS3

/// Abstraction of `AWSS3` to enable mocking.
protocol S3Client {
    /// See AWSS3.listObjectsV2
    func listObjectsV2(
        _ request: AWSS3ListObjectsV2Request,
        completionHandler: ((AWSS3ListObjectsV2Output?, Error?) -> Void)?
    )

    /// See AWSS3.getObject
    func getObject(
        _ request: AWSS3GetObjectRequest,
        completionHandler: ((AWSS3GetObjectOutput?, Error?) -> Void)?
    )
}

/// Implementation of `S3Client` backed by `AWSS3`.
final class DefaultS3Client: S3Client {
    private let awsServiceConfig: AWSServiceConfiguration

    /// Instantiates a `DefaultS3Client`.
    init(config: AWSServiceConfiguration) {
        awsServiceConfig = config
    }

    private var s3: AWSS3 {
        let s3Key = "com.sudoplatform.sitereputation.awss3"

        // This function is not annotated correctly and will return nil if
        // `register` hasn't been called. we need the type annotations to force
        // it to be optional and silence compiler warnings of the type
        // "Comparing non-optional value of type to 'nil' always returns false"
        let s3: AWSS3? = AWSS3.s3(forKey: s3Key)

        if let s3 = s3 {
            return s3
        } else {
            AWSS3.register(with: awsServiceConfig, forKey: s3Key)
            return AWSS3.s3(forKey: s3Key)
        }
    }

    func listObjectsV2(_ request: AWSS3ListObjectsV2Request, completionHandler: ((AWSS3ListObjectsV2Output?, Error?) -> Void)?) {
        return s3.listObjectsV2(request, completionHandler: completionHandler)
    }

    func getObject(_ request: AWSS3GetObjectRequest, completionHandler: ((AWSS3GetObjectOutput?, Error?) -> Void)?) {
        return s3.getObject(request, completionHandler: completionHandler)
    }
}
