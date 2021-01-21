//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SudoUser
import SudoConfigManager
import SudoLogging
import AWSCore

/// Reputation data which can inform a decision on whether to warn
/// or block a user from visiting a potentially malicious website.
public struct SiteReputation {
    /// True if the site has been reported as malicious.
    public let isMalicious: Bool
}

/// A library of functions for querying the reputation of a website using the Sudo Platform Site Reputation service.
public protocol SudoSiteReputationClient {
    /// Checks the reputation of the provided URL.
    /// - Parameters:
    ///   - url: The URL that will be checked.
    func getSiteReputation(url: String) -> Result<SiteReputation, SiteReputationCheckError>

    /// Retrieves the latest site reputation data from the Sudo Platform Site Reputation service.
    /// - Parameters:
    ///   - completion: Called once when reputation data has been updated or an error occurs.
    func update(completion: @escaping (Result<Void, SiteReputationUpdateError>) -> Void)

    /// The timestamp of the site reputation data fetched by the last call to `update`,
    /// or `nil` if there is no site reputation data stored locally.
    var lastUpdatePerformedAt: Date? { get }

    /// Clears all locally cached data created by the SudoSiteReputation SDK.
    /// Cancels any in-progress calls to `update`, causing them to return an error.
    func clearStorage() throws
}

/// An error raised by `SudoSiteReputationClient.getSiteReputation`.
public enum SiteReputationCheckError: Error {
    /// Reputation data is not present. Call `update` to obtain the latest reputation data.
    case reputationDataNotPresent
}

/// An error raised by `SudoSiteReputationClient.update`.
public enum SiteReputationUpdateError: Error {
    /// An outstanding call to `update` or `clearStorage` is already in progress.
    case alreadyInProgress

    /// The update process was cancelled by a call to `clearStorage`.
    case cancelled

    /// An error occurred when accessing the Sudo Platform Site Reputation Service.
    case serviceError(_ underylingError: Error)
}

/// Default implementation of `SiteReputationClient`.
public final class DefaultSudoSiteReputationClient: SudoSiteReputationClient {
    /// An error raised when initializing the `DefaultSudoSiteReputationClient`.
    public enum ConfigurationError: Error {
        /// Failed to read sudoplatformconfig.json.
        case failedToReadConfigurationFile

        /// sudoplatformconfig.json is missing a required key.
        case missingKey

        /// Caches directory not found.
        case missingCachesDirectory
    }

    private let userClient: SudoUserClient
    private let staticDataBucket: String
    private let s3: S3Client
    private let cache: Cache

    private var maliciousDomainList: [String]?
    private var cancelInProgressUpdate: (() -> Void)?

    /// Can be used to adjust the verbosity of logging output at runtime.
    public var logLevel: LogLevel = {
    #if DEBUG
        return .debug
    #else
        return .info
    #endif
    }()

    /// Instantiates a `DefaultSiteReputationClient`.
    public convenience init(
        userClient: SudoUserClient,
        storageNamespace: String = "main"
    ) throws {
        guard let configManager = DefaultSudoConfigManager() else {
            throw ConfigurationError.failedToReadConfigurationFile
        }

        guard let identityConfig = configManager.getConfigSet(namespace: "identityService"),
              let region = identityConfig["region"] as? String,
              let poolId = identityConfig["poolId"] as? String,
              let identityPoolId = identityConfig["identityPoolId"] as? String,
              let staticDataBucket = identityConfig["staticDataBucket"] as? String else {
            throw ConfigurationError.missingKey
        }

        // this constructor always returns a non-nil value
        let awsServiceConfig = AWSServiceConfiguration(
            region: region.aws_regionTypeValue(),
            credentialsProvider: AWSCognitoCredentialsProvider(
                regionType: region.aws_regionTypeValue(),
                identityPoolId: identityPoolId,
                identityProviderManager: IdentityProviderManager(
                    client: userClient,
                    region: region,
                    poolId: poolId
                )
            )
        )!

        let fileManager = FileManager.default
        guard let cacheDirectory = fileManager
                .urls(for: .cachesDirectory, in: .userDomainMask)
                .last?
                .appendingPathComponent("reputation-lists")
                .appendingPathComponent(storageNamespace) else {
            throw ConfigurationError.missingCachesDirectory
        }

        self.init(
            staticDataBucket: staticDataBucket,
            userClient: userClient,
            s3Client: DefaultS3Client(config: awsServiceConfig),
            cache: DiskCacheAccessor(
                fileManager: fileManager,
                directory: cacheDirectory
            )
        )
    }

    internal init(
        staticDataBucket: String,
        userClient: SudoUserClient,
        s3Client: S3Client,
        cache: CacheAccessor
    ) {
        self.staticDataBucket = staticDataBucket
        self.userClient = userClient
        self.s3 = s3Client
        self.cache = Cache(accessor: cache)

        self.populateInitialDomainsFromCache()
    }

    private var logger: Logger {
        // This is a computed property so that we re-create the logger
        // on each access in order to pick up changes to `logLevel`.
        return Logger(
            identifier: "com.sudoplatform.sitereputation",
            driver: NSLogDriver(level: logLevel)
        )
    }

    public func getSiteReputation(url: String) -> Result<SiteReputation, SiteReputationCheckError> {
        guard let maliciousDomainList = self.maliciousDomainList else {
            return .failure(.reputationDataNotPresent)
        }

        let domain = URL(string: url)?.host
            ?? URL(string: "https://\(url)")?.host
            ?? url

        // Use hasSuffix as a naive way to catch subdomains.
        let isMalicious = maliciousDomainList.contains(where: {
            domain == $0 || domain.hasSuffix(".\($0)")
        })

        return .success(SiteReputation(isMalicious: isMalicious))
    }

    /// Responsible for populating `maliciousDomainList` with cached lists if present.
    /// Must only be called once from `init` or optionally after `clearStorage`.
    private func populateInitialDomainsFromCache() {
        // Since this is only called from init we expect `access` to succeed.
        // Otherwise rely on the user calling `update` before trying to check.
        guard let cache = self.cache.tryAccess() else {
            maliciousDomainList = nil
            return
        }

        let lists: [MaliciousDomainList]
        switch cache.get() {
        case .success(let cachedLists):
            lists = cachedLists
        case .failure(let error):
            logger.error("Failed to read cached lists: \(error.localizedDescription)")
            maliciousDomainList = nil
            return
        }

        // It is more likely that an empty cache signifies "data not present"
        // than "service contains no lists", so flag data as not present then.
        guard !lists.isEmpty else {
            maliciousDomainList = nil
            return
        }

        maliciousDomainList = lists.map(parseDomainList).flatMap { $0 }
    }

    public var lastUpdatePerformedAt: Date? {
        return cache.lastUpdatePerformedAt
    }

    public func update(completion: @escaping (Result<Void, SiteReputationUpdateError>) -> Void) {
        var cacheRef = self.cache.tryAccess()
        guard cacheRef != nil else {
            // If an update or reset is already in progress, do nothing.
            return completion(.failure(.alreadyInProgress))
        }

        // Allow cancelling an in-progress update and releasing the cache ref.
        // This assignment is safe since we hold the cache lock.
        // NOTE: This closure must be released before calling completion.
        self.cancelInProgressUpdate = { cacheRef = nil }

        let s3 = self.s3
        let logger = self.logger
        let bucket = self.staticDataBucket

        listMaliciousDomainLists(s3: s3, logger: logger, bucket: bucket) { result in
            switch result {
            case .success(let keys):
                let queue = DispatchQueue(label: "com.sudoplatform.sitereputation.update")
                let dispatchGroup = DispatchGroup()
                var maliciousDomainList: [String] = []
                var failure: FetchMaliciousDomainListError?
                var cancelled = false

                keys.forEach { key in
                    // Attempt to read the old list version from the cache.
                    let existingList: MaliciousDomainList?
                    switch cacheRef?.get(key: key) {
                    case .none:
                        queue.sync { cancelled = true }
                        return
                    case .success(let list):
                        existingList = list
                    case .failure(let error):
                        logger.error("Failed to read cached list: \(error.localizedDescription)")
                        existingList = nil
                    }

                    // Skip fetching the list if the ETag matches what is cached.
                    if let existingList = existingList, key.eTag == existingList.eTag {
                        queue.sync { maliciousDomainList += parseDomainList(existingList) }
                        return
                    }

                    dispatchGroup.enter()

                    fetchMaliciousDomainList(s3: s3, logger: logger, key: key) { result in
                        defer { dispatchGroup.leave() }

                        switch result {
                        case .success(let newList):
                            // Attempt to put the new list in the cache.
                            switch cacheRef?.put(list: newList) {
                            case .none:
                                queue.sync { cancelled = true }
                            case .success: break
                            case .failure(let error):
                                logger.error("Failed to update cached list: \(error.localizedDescription)")
                            }

                            // Add the new list contents to the list of domains.
                            queue.sync { maliciousDomainList += parseDomainList(newList) }

                        case .failure(let error):
                            logger.error("Failed to fetch list: \(error.localizedDescription)")

                            // If the network update failed, use the existing list or [].
                            queue.sync {
                                maliciousDomainList += existingList.map(parseDomainList) ?? []
                                failure = error
                            }
                        }
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    if cancelled {
                        return completion(.failure(.cancelled))
                    }

                    self.cancelInProgressUpdate = nil
                    self.maliciousDomainList = maliciousDomainList

                    if let failure = failure {
                        return completion(.failure(.serviceError(failure)))
                    } else {
                        cacheRef?.lastUpdatePerformedAt = Date()
                        return completion(.success(()))
                    }
                }
            case .failure(let error):
                self.cancelInProgressUpdate = nil
                return completion(.failure(.serviceError(error)))
            }
        }
    }

    public func clearStorage() throws {
        // Clear the in-memory malicious domain list.
        self.maliciousDomainList = nil

        // Cancel an in-progress update call in order to release the cache.
        self.cancelInProgressUpdate?()
        self.cancelInProgressUpdate = nil

        // Block until we can access the cache to clear persistent storage.
        try self.cache.access().reset().get()
    }
}

/// Helper function that parses the body of a `MaliciousDomainList` to a list of domains.
private let parseDomainList: (MaliciousDomainList) -> [String] = { list in
    String(decoding: list.body, as: UTF8.self).components(separatedBy: "\n")
}
