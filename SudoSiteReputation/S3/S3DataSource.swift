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

/// Returns a list of identifiers corresponding to malicious filter list objects in S3.
/// - Parameters:
///   - s3: S3 client.
///   - logger: Logger.
///   - bucket: Bucket to query. This is the typically Identity Service Static Data Bucket.
func listMaliciousDomainListKeys(s3: S3Client,
                                 logger: Logger,
                                 bucket: String) async throws -> [MaliciousDomainListKey] {
    // Build request
    let request = AWSS3ListObjectsV2Request()!
    request.bucket = bucket
    request.prefix = "/reputation-lists/"

    // Get all objects from request
    let objects = try await listAllS3Objects(s3: s3, logger: logger, request: request)
    let keys: [MaliciousDomainListKey] = objects.compactMap { object in
        // Ensure both key and eTag exist on object.
        guard let key = object.key else {
            // If the key is nil, then there's nothing we can say about it.
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

    return keys
}

// MARK: - fetchMaliciousDomainList

/// An error raised by `fetchMaliciousDomainList`.
enum FetchMaliciousDomainListError: Error {
    /// An error occurred when accessing AWS S3.
    case s3Error(S3Error)

    /// An S3 object is missing required metadata.
    case missingMetadata
}

/// Fetches a single malicious domain list object from S3.
/// - Parameters:
///   - s3: S3 client.
///   - logger: Logger.
///   - key: Identifier of the malicious domain list object from `listMaliciousDomainLists`.
func fetchMaliciousDomainList( s3: S3Client, logger: Logger, key: MaliciousDomainListKey ) async throws -> MaliciousDomainList {
    let request = AWSS3GetObjectRequest()!
    request.bucket = key.bucket
    request.key = key.key

    let output = try await s3.getObject(request)
    guard let output = output else {
        throw S3Error.init(underlyingError: nil)
    }

    guard let body = output.body as? Data,
          let eTag = output.eTag,
          let metadataBlobString = output.metadata?["sudoplatformblob"],
          let metadataJson = try? JSONSerialization.jsonObject(with: Data(metadataBlobString.utf8)),
          let metadata = metadataJson as? [String: Any],
          let category = metadata["categoryEnum"] as? String,
          let nameEn = metadata["name.en"] as? String
    else {
        // Log a nonfatal error
        logger.outputError(S3DataSourceNonFatal.missingMetadata(key: key.key),
                           withUserInfo: ["bucket": key.bucket, "key": key.key])

        throw FetchMaliciousDomainListError.missingMetadata
    }

    return MaliciousDomainList(key: key.key,
                               eTag: eTag,
                               category: category,
                               name: nameEn,
                               body: body)
}

// MARK: - Helpers

/// Helper function that recursively calls s3.listObjectsV2 with updated request properties
///
/// - Parameters:
///   - s3: s3 client.
///   - logger: logger.
///   - request: request, will be mutated by this method.
///   - objects: a recursively updating list of `AWSS3Object`, defaults to empty array.
///   - iterations: the number of times this function has been called. Hard limited to 10, defaults to 1.
private func listAllS3Objects(s3: S3Client,
                              logger: Logger,
                              request: AWSS3ListObjectsV2Request,
                              objects: [AWSS3Object] = [],
                              iterations: Int = 1) async throws -> [AWSS3Object] {
    var awsObjects = objects
    // Call for list objects with request
    let output = try await s3.listObjectsV2(request)
    // Add the contents to the objects array
    awsObjects.append(contentsOf: output?.contents ?? [])
    // Check if we have a continuation token
    if let nextContinuationToken = output?.nextContinuationToken {
        // This loop should not reasonable exceed 10 iterations
        if iterations > 10 {
            // Log error
            let error = S3DataSourceNonFatal.tooManyLists
            logger.error(error.localizedDescription)
            logger.outputError(error)
            // Return with updated objects
            return awsObjects
        }
        // If less than 10 iterations, then set the continuation token in the request
        request.continuationToken = nextContinuationToken
        // Recurse with the new continuation token
        return try await listAllS3Objects(s3: s3,
                                          logger: logger,
                                          request: request,
                                          objects: awsObjects,
                                          iterations: iterations + 1)
    // If there is no continuation token
    } else {
        // Return the current recursionProperties.
        return awsObjects
    }
}
