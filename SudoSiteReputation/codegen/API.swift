// swiftlint:disable all
//  This file was automatically generated and should not be edited.

import AWSAppSync

struct GraphQL {

/// Represents the scope of the search
internal enum Scope: RawRepresentable, Equatable, JSONDecodable, JSONEncodable {
  internal typealias RawValue = String
  /// Matched on domain
  case domain
  /// Matched on path
  case path
  /// Auto generated constant for unknown enum values
  case unknown(RawValue)

  internal init?(rawValue: RawValue) {
    switch rawValue {
      case "Domain": self = .domain
      case "Path": self = .path
      default: self = .unknown(rawValue)
    }
  }

  internal var rawValue: RawValue {
    switch self {
      case .domain: return "Domain"
      case .path: return "Path"
      case .unknown(let value): return value
    }
  }

  internal static func == (lhs: Scope, rhs: Scope) -> Bool {
    switch (lhs, rhs) {
      case (.domain, .domain): return true
      case (.path, .path): return true
      case (.unknown(let lhsValue), .unknown(let rhsValue)): return lhsValue == rhsValue
      default: return false
    }
  }
}

/// Represents the status of searching for a site reputation result
internal enum ReputationStatus: RawRepresentable, Equatable, JSONDecodable, JSONEncodable {
  internal typealias RawValue = String
  /// URI not found in dataset
  case notFound
  /// URI found in dataset
  case success
  /// Auto generated constant for unknown enum values
  case unknown(RawValue)

  internal init?(rawValue: RawValue) {
    switch rawValue {
      case "NotFound": self = .notFound
      case "Success": self = .success
      default: self = .unknown(rawValue)
    }
  }

  internal var rawValue: RawValue {
    switch self {
      case .notFound: return "NotFound"
      case .success: return "Success"
      case .unknown(let value): return value
    }
  }

  internal static func == (lhs: ReputationStatus, rhs: ReputationStatus) -> Bool {
    switch (lhs, rhs) {
      case (.notFound, .notFound): return true
      case (.success, .success): return true
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
        GraphQLField("categories", type: .nonNull(.list(.nonNull(.object(Category.selections))))),
        GraphQLField("scope", type: .scalar(Scope.self)),
        GraphQLField("status", type: .nonNull(.scalar(ReputationStatus.self))),
        GraphQLField("confidence", type: .scalar(Double.self)),
        GraphQLField("ttl", type: .nonNull(.scalar(Int.self))),
        GraphQLField("isMalicious", type: .scalar(Bool.self)),
      ]

      internal var snapshot: Snapshot

      internal init(snapshot: Snapshot) {
        self.snapshot = snapshot
      }

      internal init(categories: [Category], scope: Scope? = nil, status: ReputationStatus, confidence: Double? = nil, ttl: Int, isMalicious: Bool? = nil) {
        self.init(snapshot: ["__typename": "Reputation", "categories": categories.map { $0.snapshot }, "scope": scope, "status": status, "confidence": confidence, "ttl": ttl, "isMalicious": isMalicious])
      }

      internal var __typename: String {
        get {
          return snapshot["__typename"]! as! String
        }
        set {
          snapshot.updateValue(newValue, forKey: "__typename")
        }
      }

      /// Categories the URI is a member of
      internal var categories: [Category] {
        get {
          return (snapshot["categories"] as! [Snapshot]).map { Category(snapshot: $0) }
        }
        set {
          snapshot.updateValue(newValue.map { $0.snapshot }, forKey: "categories")
        }
      }

      /// Scope of the match
      internal var scope: Scope? {
        get {
          return snapshot["scope"] as? Scope
        }
        set {
          snapshot.updateValue(newValue, forKey: "scope")
        }
      }

      /// Search result status
      internal var status: ReputationStatus {
        get {
          return snapshot["status"]! as! ReputationStatus
        }
        set {
          snapshot.updateValue(newValue, forKey: "status")
        }
      }

      /// Confidence of the provided rating
      internal var confidence: Double? {
        get {
          return snapshot["confidence"] as? Double
        }
        set {
          snapshot.updateValue(newValue, forKey: "confidence")
        }
      }

      /// Time to Live - cache expiry for the response in seconds
      internal var ttl: Int {
        get {
          return snapshot["ttl"]! as! Int
        }
        set {
          snapshot.updateValue(newValue, forKey: "ttl")
        }
      }

      /// Service applied business logic of site maliciousness
      internal var isMalicious: Bool? {
        get {
          return snapshot["isMalicious"] as? Bool
        }
        set {
          snapshot.updateValue(newValue, forKey: "isMalicious")
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

      internal struct Category: GraphQLSelectionSet {
        internal static let possibleTypes = ["Category"]

        internal static let selections: [GraphQLSelection] = [
          GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
          GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
        ]

        internal var snapshot: Snapshot

        internal init(snapshot: Snapshot) {
          self.snapshot = snapshot
        }

        internal init(id: GraphQLID) {
          self.init(snapshot: ["__typename": "Category", "id": id])
        }

        internal var __typename: String {
          get {
            return snapshot["__typename"]! as! String
          }
          set {
            snapshot.updateValue(newValue, forKey: "__typename")
          }
        }

        internal var id: GraphQLID {
          get {
            return snapshot["id"]! as! GraphQLID
          }
          set {
            snapshot.updateValue(newValue, forKey: "id")
          }
        }
      }
    }
  }
}

internal struct Reputation: GraphQLFragment {
  internal static let fragmentString =
    "fragment Reputation on Reputation {\n  __typename\n  categories {\n    __typename\n    id\n  }\n  scope\n  status\n  confidence\n  ttl\n  isMalicious\n}"

  internal static let possibleTypes = ["Reputation"]

  internal static let selections: [GraphQLSelection] = [
    GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
    GraphQLField("categories", type: .nonNull(.list(.nonNull(.object(Category.selections))))),
    GraphQLField("scope", type: .scalar(Scope.self)),
    GraphQLField("status", type: .nonNull(.scalar(ReputationStatus.self))),
    GraphQLField("confidence", type: .scalar(Double.self)),
    GraphQLField("ttl", type: .nonNull(.scalar(Int.self))),
    GraphQLField("isMalicious", type: .scalar(Bool.self)),
  ]

  internal var snapshot: Snapshot

  internal init(snapshot: Snapshot) {
    self.snapshot = snapshot
  }

  internal init(categories: [Category], scope: Scope? = nil, status: ReputationStatus, confidence: Double? = nil, ttl: Int, isMalicious: Bool? = nil) {
    self.init(snapshot: ["__typename": "Reputation", "categories": categories.map { $0.snapshot }, "scope": scope, "status": status, "confidence": confidence, "ttl": ttl, "isMalicious": isMalicious])
  }

  internal var __typename: String {
    get {
      return snapshot["__typename"]! as! String
    }
    set {
      snapshot.updateValue(newValue, forKey: "__typename")
    }
  }

  /// Categories the URI is a member of
  internal var categories: [Category] {
    get {
      return (snapshot["categories"] as! [Snapshot]).map { Category(snapshot: $0) }
    }
    set {
      snapshot.updateValue(newValue.map { $0.snapshot }, forKey: "categories")
    }
  }

  /// Scope of the match
  internal var scope: Scope? {
    get {
      return snapshot["scope"] as? Scope
    }
    set {
      snapshot.updateValue(newValue, forKey: "scope")
    }
  }

  /// Search result status
  internal var status: ReputationStatus {
    get {
      return snapshot["status"]! as! ReputationStatus
    }
    set {
      snapshot.updateValue(newValue, forKey: "status")
    }
  }

  /// Confidence of the provided rating
  internal var confidence: Double? {
    get {
      return snapshot["confidence"] as? Double
    }
    set {
      snapshot.updateValue(newValue, forKey: "confidence")
    }
  }

  /// Time to Live - cache expiry for the response in seconds
  internal var ttl: Int {
    get {
      return snapshot["ttl"]! as! Int
    }
    set {
      snapshot.updateValue(newValue, forKey: "ttl")
    }
  }

  /// Service applied business logic of site maliciousness
  internal var isMalicious: Bool? {
    get {
      return snapshot["isMalicious"] as? Bool
    }
    set {
      snapshot.updateValue(newValue, forKey: "isMalicious")
    }
  }

  internal struct Category: GraphQLSelectionSet {
    internal static let possibleTypes = ["Category"]

    internal static let selections: [GraphQLSelection] = [
      GraphQLField("__typename", type: .nonNull(.scalar(String.self))),
      GraphQLField("id", type: .nonNull(.scalar(GraphQLID.self))),
    ]

    internal var snapshot: Snapshot

    internal init(snapshot: Snapshot) {
      self.snapshot = snapshot
    }

    internal init(id: GraphQLID) {
      self.init(snapshot: ["__typename": "Category", "id": id])
    }

    internal var __typename: String {
      get {
        return snapshot["__typename"]! as! String
      }
      set {
        snapshot.updateValue(newValue, forKey: "__typename")
      }
    }

    internal var id: GraphQLID {
      get {
        return snapshot["id"]! as! GraphQLID
      }
      set {
        snapshot.updateValue(newValue, forKey: "id")
      }
    }
  }
}
}