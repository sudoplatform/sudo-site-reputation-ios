//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SudoUser
import SudoConfigManager
import SudoLogging
import Foundation
import SwiftUI

public struct LegacySiteReputationClientConfig {

    // MARK: - Properties

    /// File storage namespace
    public let storageNamespace: String = "main"

    /// Where to cache files
    public let cacheDirectory: URL

    /// siteReputationService "bucket"
    public let bucket: String

    /// siteReputationService "region"
    public let region: String

    // MARK: - Lifecycle

    /// Preferred init when using a sudoplatformconfig.json file. Pulls expected values from the default SudoConfigManager.
    public init() throws {
        let defaultConfigManagerName = SudoConfigManagerFactory.Constants.defaultConfigManagerName
        guard let configManager = SudoConfigManagerFactory.instance.getConfigManager(name: defaultConfigManagerName) else {
            throw SudoSiteReputationError.invalidConfig
        }
        guard
            let siteReputationServiceConfig = configManager.getConfigSet(namespace: "siteReputationService"),
            let region = siteReputationServiceConfig["region"] as? String,
            let bucket = siteReputationServiceConfig["bucket"] as? String
        else {
            throw SudoSiteReputationError.invalidConfig
        }

        let fileManager = FileManager.default
        guard let cacheDirectory = fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .last 
        else {
            throw SudoSiteReputationError.internalError("Missing cache directory")
        }
        self.init(cacheDirectory: cacheDirectory, region: region, bucket: bucket)
    }

    public init(cacheDirectory: URL, region: String, bucket: String) {
        self.cacheDirectory = cacheDirectory
        self.region = region
        self.bucket = bucket
    }
}

/// Default implementation of `SiteReputationClient`.
public final class DefaultLegacySiteReputationClient: LegacySudoSiteReputationClient {

    // MARK: - Properties

    private let userClient: SudoUserClient
    private let logger: SudoLogging.Logger
    internal private (set) var reputationProvider: SiteReputationProvider?
    internal private (set) var maliciousDomainListProvider: MaliciousDomainListProviding

    // MARK: - Lifecycle

    public convenience init(userClient: SudoUserClient) throws {
        let config = try LegacySiteReputationClientConfig()
        try self.init(config: config, userClient: userClient)
    }

    /// Instantiates a `DefaultSiteReputationClient` using the provided configuration object.
    public convenience init(config: LegacySiteReputationClientConfig, userClient: SudoUserClient) throws {
        let logLevel: LogLevel = {
            #if DEBUG
                return .debug
            #else
                return .info
            #endif
        }()
        let logger = SudoLogging.Logger(identifier: "com.sudoplatform.sitereputation", driver: NSLogDriver(level: logLevel))
        let s3DataSource = try DefaultS3DataSource(region: config.region, logger: logger)
        let cacheDirectory = config.cacheDirectory
            .appendingPathComponent("reputation-lists")
            .appendingPathComponent(config.storageNamespace)
        let cache = DiskServiceDataCache(directory: cacheDirectory)
        self.init(
            staticDataBucket: config.bucket,
            userClient: userClient,
            s3DataSource: s3DataSource,
            cache: cache,
            logger: logger
        )
    }

    internal init(
        staticDataBucket: String,
        userClient: SudoUserClient,
        s3DataSource: S3DataSource,
        cache: ServiceDataCache,
        logger: SudoLogging.Logger
    ) {
        self.userClient = userClient
        self.maliciousDomainListProvider = MaliciousDomainListProvider(
            staticDataBucket: staticDataBucket,
            s3: s3DataSource,
            cache: cache,
            logger: logger
        )
        self.logger = logger
    }

    // MARK: - Conformance: LegacySudoSiteReputationClient

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
