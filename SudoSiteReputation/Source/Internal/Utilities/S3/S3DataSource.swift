//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Amplify
import AWSS3
import Foundation
import SudoLogging

/// Client to interact with S3.
protocol S3DataSource {

    /// Returns a list of identifiers corresponding to malicious filter list objects in S3.
    func listMaliciousDomainListKeys(bucket: String) async throws -> [MaliciousDomainListKey]

    /// Fetches a single malicious domain list object from S3.
    /// - Parameter key: Identifier of the malicious domain list object from `listMaliciousDomainLists`.
    func fetchMaliciousDomainList(key: MaliciousDomainListKey) async throws -> MaliciousDomainList
}

/// A non-fatal error encountered by the S3 data source.
enum S3DataSourceNonFatal: LocalizedError {

    /// Exceeded maximum number of pages of S3 data.
    case tooManyLists

    /// An S3 object with the given key is missing required metadata.
    case missingMetadata(key: String)

    // MARK: - Conformance: LocalizedError

    var errorDescription: String? {
        switch self {
        case .tooManyLists:
            return "Exceeded maximum number of pages of S3 data."
        case .missingMetadata(let key):
            return "S3 object with key '\(key)' is missing required metadata."
        }
    }
}

class DefaultS3DataSource: S3DataSource {

    // MARK: - Constants
    
    /// The maximum number of times to recursively list objects.
    let maxListIterations = 10

    // MARK: - Properties

    /// The AWS region.
    let region: String

    /// Provides AWS credentials to the S3Client.
    let credentialIdentityResolver: CredentialIdentityResolver

    /// AWS S3 Client
    let s3Client: S3Client

    /// A logging instance.
    let logger: SudoLogging.Logger

    // MARK: - Lifecycle

    init(region: String, logger: SudoLogging.Logger) throws {
        self.region = region
        self.logger = logger
        credentialIdentityResolver = CredentialIdentityResolver()
        let config = try S3Client.S3ClientConfiguration(awsCredentialIdentityResolver: credentialIdentityResolver, region: region)
        s3Client = S3Client(config: config)
    }

    // MARK: - Conformance: S3Client

    func listMaliciousDomainListKeys(bucket: String) async throws -> [MaliciousDomainListKey] {
        let objects = try await listAllObjects(bucket: bucket, prefix: "/reputation-lists/")
        let keys: [MaliciousDomainListKey] = objects.compactMap { object in
            guard let key = object.key else {
                return nil
            }
            guard let eTag = object.eTag else {
                let error = S3DataSourceNonFatal.missingMetadata(key: key)
                logger.error(error.localizedDescription)
                logger.outputError(error, withUserInfo: ["bucket": bucket, "key": key])
                return nil
            }
            return MaliciousDomainListKey(key: key, bucket: bucket, eTag: eTag)
        }
        return keys
    }

    func fetchMaliciousDomainList(key: MaliciousDomainListKey) async throws -> MaliciousDomainList {
        let input = GetObjectInput(bucket: key.bucket, key: key.key)
        let output: GetObjectOutput
        do {
            output = try await s3Client.getObject(input: input)

        } catch is NoSuchKey {
            throw S3DataSourceError.noSuchKey

        } catch let workerError as S3DataSourceError {
            throw workerError

        } catch {
            throw S3DataSourceError.serviceError(cause: error)
        }
        let body: Data?
        do {
            body = try await output.body?.readData()
        } catch {
            throw S3DataSourceError.failedToReadData(cause: error)
        }
        guard let body else {
            throw S3DataSourceError.dataMissing
        }
        guard
            let eTag = output.eTag,
            let metadataBlobString = output.metadata?["sudoplatformblob"],
            let metadataJson = try? JSONSerialization.jsonObject(with: Data(metadataBlobString.utf8)),
            let metadata = metadataJson as? [String: Any],
            let category = metadata["categoryEnum"] as? String,
            let nameEn = metadata["name.en"] as? String
        else {
            let error = S3DataSourceNonFatal.missingMetadata(key: key.key)
            logger.outputError(error, withUserInfo: ["bucket": key.bucket, "key": key.key])
            throw S3DataSourceError.missingMetadata(key: key.key)
        }
        return MaliciousDomainList(
            key: key.key,
            eTag: eTag,
            category: category,
            name: nameEn,
            body: body
        )
    }

    // MARK: - Helpers

    func listAllObjects(bucket: String, prefix: String) async throws -> [S3ClientTypes.Object] {
        var objects: [S3ClientTypes.Object] = []
        var nextContinuationToken: String?

        for _ in 0 ..< maxListIterations {
            do {
                let input = ListObjectsV2Input(bucket: bucket, continuationToken: nextContinuationToken, prefix: prefix)
                let output = try await s3Client.listObjectsV2(input: input)
                if let contents = output.contents {
                    objects.append(contentsOf: contents)
                }
                nextContinuationToken = output.nextContinuationToken
                if output.nextContinuationToken == nil {
                    return objects
                }
            } catch {
                throw S3DataSourceError.serviceError(cause: error)
            }
        }
        // This loop should not reasonably exceed 10 iterations
        let error = S3DataSourceNonFatal.tooManyLists
        logger.error(error.localizedDescription)
        logger.outputError(error)
        return objects
    }
}

