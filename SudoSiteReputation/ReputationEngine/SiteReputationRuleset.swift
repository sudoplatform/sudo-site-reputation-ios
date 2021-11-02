//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

// Ruleset is a list of rules and relevant metadata we know about the rules.
struct SiteReputationRuleset {

    typealias RuleHost = String
    typealias RulePath = String

    // key of the source data this ruleset was generated from
    let key: String

    // category, e.g. malware, phishing
    let category: String

    // name of the ruleset
    let name: String

    // Lookup table for the rules in this ruleset
    // Rules are keyed by the domain/host for quick lookup.
    let lookupTable: [RuleHost: RulePath]

    internal init(key: String, category: String, name: String, rules: [SiteReputationRule]) {
        self.key = key
        self.category = category
        self.name = name

        var table: [RuleHost: RulePath] = [:]
        for rule in rules {
            table[rule.host] = rule.path
        }
        self.lookupTable = table
    }
}

// Site reputation rule is a host + optional path. e.g. "www.malware.com"
// or "www.sharedHostingProvider.com/bad_actor"
struct SiteReputationRule {
    let host: String
    let path: String

    init(host: String, path: String) {
        self.host = host
        self.path = path
    }

    // Attempt to parse host + path from what looks like a url string.
    init?(urlString: String) {
        guard let parsedValues = hostAndPathFrom(maybeURLString: urlString) else {
            return nil
        }

        self.host = parsedValues.host
        self.path = parsedValues.path
    }
}

typealias HostAndPath = (host: String, path: String)

// The URL api doesn't work directly to parse host and path because the string may be missing a scheme.
func hostAndPathFrom(maybeURLString: String) -> HostAndPath? {
    // try direct init
    var maybeURL = URL(string: maybeURLString)

    // If it failed maybe it's missing a scheme
    if maybeURL?.host == nil {
        maybeURL = URL(string: "https://" + maybeURLString)
    }

    if let host = maybeURL?.host {
        return (host, maybeURL?.path ?? "")
    } else {
        return nil
    }
}
