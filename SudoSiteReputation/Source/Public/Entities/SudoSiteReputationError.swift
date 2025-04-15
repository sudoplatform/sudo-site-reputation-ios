//
// Copyright © 2025 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import struct Amplify.GraphQLError
import enum Amplify.JSONValue
import Foundation
import SudoApiClient

/// Errors that occur in SudoSiteReputation.
public enum SudoSiteReputationError: Error, Equatable, LocalizedError {

    // MARK: - Client

    /// Configuration supplied to the client is invalid.
    case invalidConfig

    /// User is not signed in.
    case notSignedIn

    // MARK: - Service

    /// Indicates the requested operation failed because the user account is locked.
    case accountLocked

    /// Indicates that the request operation failed due to authorization error. This maybe due to the authentication
    /// token being invalid or other security controls that prevent the user from accessing the API.
    case notAuthorized

    /// Indicates API call  failed due to it exceeding some limits imposed for the API. For example, this error
    /// can occur if the vault size was too big.
    case limitExceeded

    /// Indicates that the user does not have sufficient entitlements to perform the requested operation.
    case insufficientEntitlements

    /// Indicates the version of the vault that is getting updated does not match the current version of the vault stored
    /// in the backend. The caller should retrieve the current version of the vault and reconcile the difference.
    case versionMismatch

    /// Indicates that an internal server error caused the operation to fail. The error is possibly transient and
    /// retrying at a later time may cause the operation to complete successfully
    case serviceError

    /// Indicates that there were too many attempts at sending API requests within a short period of time.
    case rateLimitExceeded

    /// Operation failed due to an invalid request. This maybe due to the version mismatch between the
    /// client and the backend.
    case invalidRequest

    /// Indicates that the request failed due to connectivity, availability or access error.
    case requestFailed(response: HTTPURLResponse?, cause: Error?)

    /// Indicates that a GraphQL error was returned by the backend.
    case graphQLError(description: String)

    /// Indicates that a fatal error occurred. This could be due to coding error, out-of-memory condition or other
    /// conditions that is beyond control of `SudoIdentityVerificationClient` implementation.
    case fatalError(description: String)

    /// Backend environment error occurred.
    case environmentError

    /// Returned when JSON web tokens submitted are rejected because they:
    ///     1. fail signature verification
    ///     2. is not an appropriate token for the invoker user to be submitting (e.g. user id doesn't match)
    ///     3. is a resource reference token for resource type unrecognized by the service
    ///        to which the token has been submitted
    case invalidToken

    /// Returned when the user has no entitlements associated with them
    case noEntitlements

    /// An internal error has occurred and will need to be resolved by Anonyome.
    case internalError(_ cause: String?)

    /// Returned if an API argument is not valid or inconsistent with other arguments.
    case invalidArgument(_ msg: String?)

    /// Returned when the input was not in the expected format.
    case decodingError

    // MARK: - Lifecycle

    /// Initialize a `SudoVirtualCardsError` from a `GraphQLError`.
    ///
    /// If the GraphQLError is unsupported, `nil` will be returned instead.
    init(graphQLError error: GraphQLError) { // swiftlint:disable:this cyclomatic_complexity
        guard let errorType = error.extensions?["errorType"]?.stringValue else {
            self = .internalError(error.message)
            return
        }
        switch errorType {
        case "sudoplatform.AccountLockedError":
            self = .accountLocked
        case "sudoplatform.DecodingError":
            self = .decodingError
        case "sudoplatform.EnvironmentError":
            self = .environmentError
        case "sudoplatform.InsufficientEntitlementsError":
            self = .insufficientEntitlements
        case "sudoplatform.InvalidArgumentError":
            let msg = error.message.isEmpty ? nil : error.message
            self = .invalidArgument(msg)
        case "sudoplatform.InvalidTokenError":
            self = .invalidToken
        case "sudoplatform.NoEntitlementsError":
            self = .noEntitlements
        case "sudoplatform.ServiceError":
            self = .serviceError
        default:
            self = .internalError("\(errorType) - \(error.message)")
        }
    }

    // MARK: - Conformance: Equatable

    public static func == (lhs: SudoSiteReputationError, rhs: SudoSiteReputationError) -> Bool {
        switch (lhs, rhs) {
        case (.requestFailed(let lhsResponse, let lhsCause), requestFailed(let rhsResponse, let rhsCause)):
            if let lhsResponse = lhsResponse, let rhsResponse = rhsResponse {
                return lhsResponse.statusCode == rhsResponse.statusCode
            }
            return type(of: lhsCause) == type(of: rhsCause)
        case (.accountLocked, .accountLocked),
             (.environmentError, .environmentError),
             (.fatalError, .fatalError),
             (.graphQLError, .graphQLError),
             (.insufficientEntitlements, .insufficientEntitlements),
             (.internalError, .internalError),
             (.invalidArgument, .invalidArgument),
             (.invalidConfig, .invalidConfig),
             (.invalidRequest, .invalidRequest),
             (.invalidToken, .invalidToken),
             (.limitExceeded, .limitExceeded),
             (.noEntitlements, .noEntitlements),
             (.notAuthorized, .notAuthorized),
             (.notSignedIn, .notSignedIn),
             (.rateLimitExceeded, .rateLimitExceeded),
             (.serviceError, .serviceError),
             (.versionMismatch, .versionMismatch):
            return true
        default:
            return false
        }
    }

    // MARK: - Conformance: LocalizedError

    public var errorDescription: String? {
        switch self {
        case .accountLocked:
            return L10n.SiteReputation.Errors.accountLockedError
        case .environmentError:
            return L10n.SiteReputation.Errors.environmentError
        case .invalidConfig:
            return L10n.SiteReputation.Errors.invalidConfig
        case .invalidRequest:
            return L10n.SiteReputation.Errors.invalidRequest
        case .notSignedIn:
            return L10n.SiteReputation.Errors.notSignedIn
        case .serviceError:
            return L10n.SiteReputation.Errors.serviceError
        case .invalidToken:
            return L10n.SiteReputation.Errors.invalidTokenError
        case .noEntitlements:
            return L10n.SiteReputation.Errors.noEntitlementsError
        case .insufficientEntitlements:
            return L10n.SiteReputation.Errors.insufficientEntitlementsError
        case let .internalError(cause):
            return cause ?? "Unknown error"
        case let .invalidArgument(msg):
            return msg ?? L10n.SiteReputation.Errors.invalidArgument
        case .notAuthorized:
            return L10n.SiteReputation.Errors.notAuthorized
        case .limitExceeded:
            return L10n.SiteReputation.Errors.limitExceeded
        case .versionMismatch:
            return L10n.SiteReputation.Errors.versionMismatch
        case .requestFailed:
            return L10n.SiteReputation.Errors.requestFailed
        case .rateLimitExceeded:
            return L10n.SiteReputation.Errors.rateLimitExceeded
        case .graphQLError:
            return L10n.SiteReputation.Errors.graphQLError
        case .fatalError(let msg):
            return "\(L10n.SiteReputation.Errors.fatalError): \(msg)"
        case .decodingError:
            return L10n.SiteReputation.Errors.decodingError
        }
    }
}

extension SudoSiteReputationError {

    struct Constants {
        static let errorType = "errorType"
    }

    static func fromApiOperationError(error: Error) -> SudoSiteReputationError {
        if let siteReputationError = error as? SudoSiteReputationError {
            return siteReputationError
        }
        switch error {
        case ApiOperationError.accountLocked:
            return .accountLocked
        case ApiOperationError.invalidRequest:
            return .invalidRequest
        case ApiOperationError.notSignedIn:
            return .notSignedIn
        case ApiOperationError.notAuthorized:
            return .notAuthorized
        case ApiOperationError.limitExceeded:
            return .limitExceeded
        case ApiOperationError.insufficientEntitlements:
            return .insufficientEntitlements
        case ApiOperationError.serviceError:
            return .serviceError
        case ApiOperationError.versionMismatch:
            return .versionMismatch
        case ApiOperationError.rateLimitExceeded:
            return .rateLimitExceeded
        case ApiOperationError.graphQLError(let underlyingError):
            if let graphQLError = underlyingError as? GraphQLError {
                return SudoSiteReputationError(graphQLError: graphQLError)
            }
            return .graphQLError(description: "Unexpected GraphQL error: \(underlyingError.localizedDescription)")
        case ApiOperationError.requestFailed(let response, let cause):
            return .requestFailed(response: response, cause: cause)
        default:
            return .fatalError(description: "Unexpected API operation error: \(error.localizedDescription)")
        }
    }
}
