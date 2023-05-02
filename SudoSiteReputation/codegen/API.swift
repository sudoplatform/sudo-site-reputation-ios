// swiftlint:disable all
//  This file was automatically generated and should not be edited.

import AWSAppSync

struct GraphQL {

/// Represents the status of searching for a site reputation result
internal enum ReputationStatus: RawRepresentable, Equatable, JSONDecodable, JSONEncodable {
  internal typealias RawValue = String
  /// URI found in dataset as malicious
  case malicious
  /// URI not in dataset as not malicious
  case notmalicious
  /// Auto generated constant for unknown enum values
  case unknown(RawValue)

  internal init?(rawValue: RawValue) {
    switch rawValue {
      case "MALICIOUS": self = .malicious
      case "NOTMALICIOUS": self = .notmalicious
      default: self = .unknown(rawValue)
    }
  }

  internal var rawValue: RawValue {
    switch self {
      case .malicious: return "MALICIOUS"
      case .notmalicious: return "NOTMALICIOUS"
      case .unknown(let value): return value
    }
  }

  internal static func == (lhs: ReputationStatus, rhs: ReputationStatus) -> Bool {
    switch (lhs, rhs) {
      case (.malicious, .malicious): return true
      case (.notmalicious, .notmalicious): return true
      case (.unknown(let lhsValue), .unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }
}

internal final class GetSiteReputationQuery: GraphQLQuery {
  internal static let operationString =
    "query GetSiteReputation($uri: String!) {\n  getSiteReputation(uri: $uri) {\n    __typename\n    ...Reputation\n  }\n}"

  internal static var requestString: String { return operationString.appending(Reputation.fragmentString) }

  internal var uri: String

  internal init(uri: String) {
    self.uri = uri
  }

  internal var variables: GraphQLMap? {
    return ["uri": uri]
  }

  internal struct Data: GraphQLSelectionSet {
    internal static let possibleTypes = ["Query"]

    internal static let selections: [GraphQLSelection] = [
      GraphQLField("getSiteReputation", arguments: ["uri": GraphQLVariable("uri")], type: .nonNull(.object(GetSiteReputation.selections))),
    ]

    internal var snapshot: Snapshot

    internal init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    internal init(getSiteReputation: GetSiteReputation) {
      self.init(snapshot: ["__typename": "Query", "getSiteReputation": getSiteReputation.snapshot])
    }

    internal var getSiteReputation: GetSiteReputation {
      get {
        return GetSiteReputation(snapshot: snapshot["getSiteReputation"]! as! Snapshot)
      }
      set {
        snapshot.updateValue(newValue.snapshot, forKey: "getSiteReputation")
      }
    }

    internal struct GetSiteReputation: GraphQLSelectionSet {
      internal static let possibleTypes = ["Reputation"]

      internal static let selections: [GraphQLSelection] = [
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
        GraphQLField("reputationStatus", type: .nonNull(.scalar(ReputationStatus.self))),
      ]

      internal var snapshot: Snapshot

      internal init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      internal init(reputationStatus: ReputationStatus) {
        self.init(snapshot: ["__typename": "Reputation", "reputationStatus": reputationStatus])
      }

      internal var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      /// Search result status
      internal var reputationStatus: ReputationStatus {
        get {
          return snapshot["reputationStatus"]! as! ReputationStatus
        }
        set {
          snapshot.updateValue(newValue, forKey: "reputationStatus")
        }
      }

      internal var fragments: Fragments {
        get {
          return Fragments(snapshot: snapshot)
        }
        set {
          snapshot += newValue.snapshot
        }
      }

      internal struct Fragments {
        internal var snapshot: Snapshot

        internal var reputation: Reputation {
          get {
            return Reputation(snapshot: snapshot)
          }
          set {
            snapshot += newValue.snapshot
          }
        }
      }
    }
  }
}

internal struct Reputation: GraphQLFragment {
  internal static let fragmentString =
    "fragment Reputation on Reputation {\n  __typename\n  reputationStatus\n}"

  internal static let possibleTypes = ["Reputation"]

  internal static let selections: [GraphQLSelection] = [
    GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
    GraphQLField("reputationStatus", type: .nonNull(.scalar(ReputationStatus.self))),
  ]

  internal var snapshot: Snapshot

  internal init(snapshot: Snapshot) {
    self.snapshot = snapshot
  }

  internal init(reputationStatus: ReputationStatus) {
    self.init(snapshot: ["__typename": "Reputation", "reputationStatus": reputationStatus])
  }

  internal var __typename: String {
    get {
      return snapshot["__typename"]! as! String
    }
    set {
      snapshot.updateValue(newValue, forKey: "__typename")
    }
  }

  /// Search result status
  internal var reputationStatus: ReputationStatus {
    get {
      return snapshot["reputationStatus"]! as! ReputationStatus
    }
    set {
      snapshot.updateValue(newValue, forKey: "reputationStatus")
    }
  }
}
}