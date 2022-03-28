//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSS3
import SudoLogging

// MARK: - Models

/// An error occurred when accessing AWS S3.
struct S3Error: Error {
    /// The underlying error from AWS S3.
    let underlyingError: Error?
}

/// A non-fatal error encountered by the S3 data source.
enum S3DataSourceNonFatal: Error {
    /// Exceeded maximum number of pages of S3 data.
    case tooManyLists

    /// An S3 object with the given key is missing required metadata.
    case missingMetadata(key: String)
}

// MARK: - listMaliciousDomainList

/// An error raised by `listMaliciousDomainLists`.
enum ListMaliciousDomainListsError: Error {
    /// An error occurred when accessing AWS S3.
    case s3Error(S3Error)
}

typealias MaliciousDomainListResult =
    Result<[MaliciousDomainListKey], ListMaliciousDomainListsError>

/// Returns a list of identifiers corresponding to malicious filter list objects in S3.
/// - Parameters:
///   - s3: S3 client.
///   - logger: Logger.
///   - bucket: Bucket to query. This is the typically Identity Service Static Data Bucket.
///   - completion: Called once when the list of identifiers is obtained or an error occurs.
func listMaliciousDomainListKeys(
    s3: S3Client,
    logger: Logger,
    bucket: String,
    completion: @escaping (MaliciousDomainListResult) -> Void
) {
    let request = AWSS3ListObjectsV2Request()!
    request.bucket = bucket
    request.prefix = "/reputation-lists/"

    listAllS3Objects(s3: s3, logger: logger, request: request) { result in
        switch result {
        case .success(let objects):
            let keys: [MaliciousDomainListKey] = objects.compactMap { object in
                guard let key = object.key else {
                    // If the key is nil there's nothing we can say about it.
                    return nil
                }

                guard let eTag = object.eTag else {
                    // Log a nonfatal error and continue.
                    let error = S3DataSourceNonFatal.missingMetadata(key: key)
                    logger.error(error.localizedDescription)
                    logger.outputError(error, withUserInfo: ["bucket": bucket, "key": key])
                    return nil
                }

                return MaliciousDomainListKey(key: key, bucket: bucket, eTag: eTag)
            }

            return completion(.success(keys))
        case .failure(let error):
            return completion(.failure(.s3Error(error)))
        }
    }
}

// MARK: - fetchMaliciousDomainList

/// An error raised by `fetchMaliciousDomainList`.
enum FetchMaliciousDomainListError: Error {
    /// An error occurred when accessing AWS S3.
    case s3Error(S3Error)

    /// An S3 object is missing required metadata.
    case missingMetadata
}

typealias FetchMaliciousDomainListResult =
    Result<MaliciousDomainList, FetchMaliciousDomainListError>

/// Fetches a single malicious domain list object from S3.
/// - Parameters:
///   - s3: S3 client.
///   - logger: Logger.
///   - key: Identifier of the malicious domain list object from `listMaliciousDomainLists`.
///   - completion: Called once when the object is fetched or an error occurs.
func fetchMaliciousDomainList(
    s3: S3Client,
    logger: Logger,
    key: MaliciousDomainListKey,
    completion: @escaping (FetchMaliciousDomainListResult) -> Void
) {
    let request = AWSS3GetObjectRequest()!
    request.bucket = key.bucket
    request.key = key.key

    s3.getObject(request) { (output, error) in
        if let error = error {
            return completion(.failure(.s3Error(S3Error(underlyingError: error))))
        }
        guard let output = output else {
            return completion(.failure(.s3Error(S3Error(underlyingError: nil))))
        }

        guard let body = output.body as? Data,
              let eTag = output.eTag,
              let metadataBlobString = output.metadata?["sudoplatformblob"],
              let metadataJson = try? JSONSerialization.jsonObject(with: Data(metadataBlobString.utf8)),
              let metadata = metadataJson as? [String: Any],
              let category = metadata["categoryEnum"] as? String,
              let nameEn = metadata["name.en"] as? String
        else {
            // Log a nonfatal error.
            logger.outputError(
                S3DataSourceNonFatal.missingMetadata(key: key.key),
                withUserInfo: ["bucket": key.bucket, "key": key.key])

            return completion(.failure(.missingMetadata))
        }

        return completion(.success(MaliciousDomainList(
            key: key.key,
            eTag: eTag,
            category: category,
            name: nameEn,
            body: body
        )))
    }
}

// MARK: - Helpers

/// Helper function that lists all pages of S3 data for a given request.
///
/// - Parameters:
///   - s3: s3 client.
///   - logger: logger.
///   - request: request. will be mutated by this method.
///   - completion: called once when all data is available or an error occurs.
private func listAllS3Objects(
    s3: S3Client,
    logger: Logger,
    request: AWSS3ListObjectsV2Request,
    completion: @escaping (Result<[AWSS3Object], S3Error>) -> Void
) {
    var objects: [AWSS3Object] = []
    var i = 0

    var callback: ((AWSS3ListObjectsV2Output?, Error?) -> Void)!
    callback = { (output, error) in
        if let error = error {
            callback = nil
            return completion(.failure(S3Error(underlyingError: error)))
        }
        guard let output = output else {
            callback = nil
            return completion(.failure(S3Error(underlyingError: nil)))
        }

        objects.append(contentsOf: output.contents ?? [])

        if let nextContinuationToken = output.nextContinuationToken {
            // this loop should not reasonably exceed 10 iterations
            i += 1
            if i > 10 {
                let error = S3DataSourceNonFatal.tooManyLists
                logger.error(error.localizedDescription)
                logger.outputError(error)
                return completion(.success(objects))
            }

            request.continuationToken = nextContinuationToken
            s3.listObjectsV2(request, completionHandler: callback)
        } else {
            callback = nil
            return completion(.success(objects))
        }
    }

    s3.listObjectsV2(request, completionHandler: callback)
}
