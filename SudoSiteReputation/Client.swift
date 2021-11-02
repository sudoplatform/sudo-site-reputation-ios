//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SudoUser
import SudoConfigManager
import SudoLogging
import AWSCore

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
    internal private (set) var reputationProvider: SiteReputationProvider?
    internal private (set) var maliciousDomainListProvider: MaliciousDomainListProviding

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
        config: SudoConfigManager? = nil,
        storageNamespace: String = "main"
    ) throws {

        guard let configManager = config ?? DefaultSudoConfigManager() else {
            throw ConfigurationError.failedToReadConfigurationFile
        }

        guard let identityConfig = configManager.getConfigSet(namespace: "identityService"),
              let poolId = identityConfig["poolId"] as? String,
              let identityPoolId = identityConfig["identityPoolId"] as? String else {
            throw ConfigurationError.missingKey
        }

        guard let siteReputationServiceConfig = configManager.getConfigSet(namespace: "siteReputationService"),
              let region = siteReputationServiceConfig["region"] as? String,
              let bucket = siteReputationServiceConfig["bucket"] as? String else {
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
            staticDataBucket: bucket,
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
        self.userClient = userClient
        self.maliciousDomainListProvider = MaliciousDomainListProvider(
            staticDataBucket: staticDataBucket,
            s3: s3Client,
            cache: Cache(accessor: cache),
            logger: Logger(
                identifier: "com.sudoplatform.sitereputation",
                driver: NSLogDriver(level: logLevel
                )
            )
        )

        self.loadInitialData()
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
        guard let reputationProvider = self.reputationProvider else {
            return .failure(.reputationDataNotPresent)
        }

        let matchReason = reputationProvider.check(url: url)
        return .success(SiteReputation(isMalicious: matchReason != nil))
    }

    /// Responsible for populating the ruleset engine with cached lists if present.
    /// Must only be called once from `init` or optionally after `clearStorage`.
    private func loadInitialData() {
        guard let lists = self.maliciousDomainListProvider.fetchMaliciousDomainLists() else {
            return
        }

        let rulesets = lists.compactMap {MaliciousDomainListTransformer.transform(list: $0)}
        reputationProvider = SiteReputationProvider(rulesets: rulesets)
    }

    public func update(completion: @escaping (Result<Void, SiteReputationUpdateError>) -> Void) {
        self.maliciousDomainListProvider.update { [weak self] result in
            switch result {
            case .success(let lists):
                let rulesets = lists.compactMap {MaliciousDomainListTransformer.transform(list: $0)}
                self?.reputationProvider = SiteReputationProvider(rulesets: rulesets)
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public var lastUpdatePerformedAt: Date? {
        return maliciousDomainListProvider.lastUpdatePerformedAt
    }

    public func clearStorage() throws {
        // Clear the in-memory malicious domain list.
        self.reputationProvider = nil

        // clear any cached data
        try self.maliciousDomainListProvider.clearStorage()
    }
}
