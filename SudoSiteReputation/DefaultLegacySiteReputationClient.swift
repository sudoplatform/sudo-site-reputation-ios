//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SudoUser
import SudoConfigManager
import SudoLogging
import AWSCore
import Foundation
import SwiftUI

public struct LegacySiteReputationClientConfig {

    /// An error raised when initializing the `DefaultSudoSiteReputationClient`.
    public enum ConfigurationError: Error {
        /// Failed to read sudoplatformconfig.json.
        case failedToReadConfigurationFile

        /// sudoplatformconfig.json is missing a required key.
        case missingKey

        /// Caches directory not found.
        case missingCachesDirectory
    }

    public init(
        userClient: SudoUserClient,
        cacheDirectory: URL,
        region: String,
        identityPoolId: String,
        poolId: String,
        bucket: String
    ) {
        self.userClient = userClient
        self.cacheDirectory = cacheDirectory
        self.region = region
        self.identityPoolId = identityPoolId
        self.poolId = poolId
        self.bucket = bucket
    }

    // SudoUserClient for identity and authorization.
    public let userClient: SudoUserClient

    // File storage namespace
    public let storageNamespace: String = "main"

    // Where to cache files
    public let cacheDirectory: URL

    // identityService "identityPoolId"
    public let identityPoolId: String

    // identityService "poolId"
    public let poolId: String

    // siteReputationService "bucket"
    public let bucket: String

    // siteReputationService "region"
    public let region: String

    /// Preferred init when using a sudoplatformconfig.json file. Pulls expected values from the SudoConfigManager.
    public init(
        userClient: SudoUserClient,
        configManager: SudoConfigManager? = nil
    ) throws {
        guard let configManager = configManager ?? DefaultSudoConfigManager() else {
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

        let fileManager = FileManager.default
        guard let cacheDirectory = fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .last else {
            throw ConfigurationError.missingCachesDirectory
        }

        self.init(
            userClient: userClient,
            cacheDirectory: cacheDirectory,
            region: region,
            identityPoolId: identityPoolId,
            poolId: poolId,
            bucket: bucket
        )
    }

    var s3Config: AWSServiceConfiguration {
        // this constructor always returns a non-nil value
        return AWSServiceConfiguration(
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
    }
}

extension DefaultLegacySiteReputationClient {
    @available(*, deprecated, message: "Use SiteReputationClientConfig.ConfigurationError")
    public typealias ConfigurationError = LegacySiteReputationClientConfig.ConfigurationError
}

/// Default implementation of `SiteReputationClient`.
public final class DefaultLegacySiteReputationClient: LegacySudoSiteReputationClient {

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

    public convenience init(userClient: SudoUserClient) throws {
        self.init(config: try LegacySiteReputationClientConfig(userClient: userClient))
    }

    /// Instantiates a `DefaultSiteReputationClient` using the provided configuration object.
    public convenience init(config: LegacySiteReputationClientConfig) {
        let cacheDirectory = config.cacheDirectory
            .appendingPathComponent("reputation-lists")
            .appendingPathComponent(config.storageNamespace)

        self.init(
            staticDataBucket: config.bucket,
            userClient: config.userClient,
            s3Client: DefaultS3Client(config: config.s3Config),
            cache: DiskServiceDataCache(
                fileManager: FileManager.default,
                directory: cacheDirectory
            )
        )
    }

    internal init(
        staticDataBucket: String,
        userClient: SudoUserClient,
        s3Client: S3Client,
        cache: ServiceDataCache
    ) {
        self.userClient = userClient
        self.maliciousDomainListProvider = MaliciousDomainListProvider(
            staticDataBucket: staticDataBucket,
            s3: s3Client,
            cache: cache,
            logger: Logger(
                identifier: "com.sudoplatform.sitereputation",
                driver: NSLogDriver(level: logLevel
                )
            )
        )
    }

    private var logger: Logger {
        // This is a computed property so that we re-create the logger
        // on each access in order to pick up changes to `logLevel`.
        return Logger(
            identifier: "com.sudoplatform.sitereputation",
            driver: NSLogDriver(level: logLevel)
        )
    }

    public func getSiteReputation(url: String) async throws -> LegacySiteReputation {
        guard let reputationProvider = self.reputationProvider else {
            throw LegacySiteReputationCheckError.reputationDataNotPresent
        }

        let matchReason = reputationProvider.check(url: url)
        return LegacySiteReputation(isMalicious: matchReason != nil)
    }

    /// Responsible for populating the ruleset engine with cached lists if present.
    public func loadCachedData() async {
        guard let lists = await self.maliciousDomainListProvider.fetchMaliciousDomainLists() else {
            return
        }

        let rulesets = lists.compactMap {MaliciousDomainListTransformer.transform(list: $0)}
        reputationProvider = SiteReputationProvider(rulesets: rulesets)
    }

    public func update() async throws {
        try await self.maliciousDomainListProvider.update()
        if let lists = await self.maliciousDomainListProvider.fetchMaliciousDomainLists() {
            let rulesets = lists.compactMap { MaliciousDomainListTransformer.transform(list: $0)}
            self.reputationProvider = SiteReputationProvider(rulesets: rulesets)
        }
    }

    public func lastUpdatePerformedAt() async -> Date? {
        return await maliciousDomainListProvider.lastUpdatePerformedAt()
    }

    public func clearStorage() async throws {
        // Clear the in-memory malicious domain list.
        self.reputationProvider = nil

        // clear any cached data
        try await self.maliciousDomainListProvider.clearStorage()
    }
}
