// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen
// Custom template in `swiftgen/strings/template.stencil`

import Foundation

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// swiftlint:disable explicit_type_interface identifier_name line_length nesting type_body_length type_name

internal enum L10n {

    // MARK: - site_reputation
    internal enum SiteReputation {
      // MARK: - errors
      internal enum Errors {
        internal static let accountLockedError = L10n.tr("Localizable", "site_reputation.errors.accountLockedError")
        internal static let decodingError = L10n.tr("Localizable", "site_reputation.errors.decodingError")
        internal static let environmentError = L10n.tr("Localizable", "site_reputation.errors.environmentError")
        internal static let fatalError = L10n.tr("Localizable", "site_reputation.errors.fatalError")
        internal static let graphQLError = L10n.tr("Localizable", "site_reputation.errors.graphQLError")
        internal static let identityInsufficient = L10n.tr("Localizable", "site_reputation.errors.identityInsufficient")
        internal static let identityNotVerified = L10n.tr("Localizable", "site_reputation.errors.identityNotVerified")
        internal static let insufficientEntitlementsError = L10n.tr("Localizable", "site_reputation.errors.insufficientEntitlementsError")
        internal static let invalidArgument = L10n.tr("Localizable", "site_reputation.errors.invalidArgument")
        internal static let invalidConfig = L10n.tr("Localizable", "site_reputation.errors.invalidConfig")
        internal static let invalidRequest = L10n.tr("Localizable", "site_reputation.errors.invalidRequest")
        internal static let invalidTokenError = L10n.tr("Localizable", "site_reputation.errors.invalidTokenError")
        internal static let limitExceeded = L10n.tr("Localizable", "site_reputation.errors.limitExceeded")
        internal static let noEntitlementsError = L10n.tr("Localizable", "site_reputation.errors.noEntitlementsError")
        internal static let notAuthorized = L10n.tr("Localizable", "site_reputation.errors.notAuthorized")
        internal static let notSignedIn = L10n.tr("Localizable", "site_reputation.errors.notSignedIn")
        internal static let rateLimitExceeded = L10n.tr("Localizable", "site_reputation.errors.rateLimitExceeded")
        internal static let requestFailed = L10n.tr("Localizable", "site_reputation.errors.requestFailed")
        internal static let serviceError = L10n.tr("Localizable", "site_reputation.errors.serviceError")
        internal static let unknownTimezone = L10n.tr("Localizable", "site_reputation.errors.unknownTimezone")
        internal static let versionMismatch = L10n.tr("Localizable", "site_reputation.errors.versionMismatch")
        // MARK: - cacheAccessError
        internal enum CacheAccessError {
          internal static func codableError(_ p1: String) -> String {
            return L10n.tr("Localizable", "site_reputation.errors.cacheAccessError.codableError", p1)
          }
          internal static func storageError(_ p1: String) -> String {
            return L10n.tr("Localizable", "site_reputation.errors.cacheAccessError.storageError", p1)
          }
        }
      }
    }
}

// swiftlint:enable explicit_type_interface identifier_name line_length nesting type_body_length type_name

extension L10n {
  fileprivate static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, tableName: table, bundle: .module, comment: "")
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
