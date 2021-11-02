//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Object that provides site reputation checking functionality.
protocol SiteReputationProviding {

    /// Checks the input URL host and path against the site reputation rules
    /// looking for a match
    /// - Parameter inputURL: the input url to check.
    /// - Returns: A match if one was found, otherwise nil
    func check(url inputURL: String) -> SiteReputationMatchReason?
}

class SiteReputationProvider: SiteReputationProviding {

    private var rulesets: [SiteReputationRuleset]

    init(rulesets: [SiteReputationRuleset]) {
        self.rulesets = rulesets
    }

    func set(rulesets: [SiteReputationRuleset]) {
        self.rulesets = rulesets
    }

    /// Checks the input URL host and path against the site reputation rules
    /// looking for a match. Attempts to match a direct input domain to a rule domain
    /// or subdomain.  Also checks the rule path to match specific resources.
    /// - Parameter inputURL: the input url to check.
    /// - Returns: A match if one was found, otherwise nil
    func check(url inputURL: String) -> SiteReputationMatchReason? {
        guard let inputComponents = hostAndPathFrom(maybeURLString: inputURL) else {
            return nil
        }

        for set in self.rulesets {

            var inputHostComponents = ArraySlice(inputComponents.host.components(separatedBy: "."))

            // Look for an exact domain match or a subdomain.
            // The simplest way to look is to pop each domain component off one
            // at a time and see if we find a match.
            // i.e. foo.bar.baz.dog.virus.malware.com would match virus.malware.com once
            // "foo.bar.baz.dog" removed.
            repeat {
                defer { inputHostComponents = inputHostComponents.dropFirst() }

                // Current subdomain might be the full domain, at least on the first loop.
                let currentSubdomain = inputHostComponents.joined(separator: ".")

                guard let domainMatch = set.lookupTable[currentSubdomain] else {
                    continue
                }

                // A match of the domain or subdomain was found.
                // Combine the rule domain (key) and value (path) found in the lookup
                // table into a host + path combo
                return resolveMatchTypeFor(input: inputComponents,
                                           rule: HostAndPath(currentSubdomain, domainMatch))
            } while inputHostComponents.isEmpty == false
        }

        return nil
    }

    // Helper function to determine what kind of match may have been found
    // if a domain/subdomain match was found.
    private func resolveMatchTypeFor(input: HostAndPath, rule: HostAndPath) -> SiteReputationMatchReason? {

        // If there is a rule with just a domain, then compare just the domain of the input.
        // i.e. input of "malware.com/virus.exe" would be flagged by a rule with domain "malware.com"
        if rule.path.isEmpty {
            if input.host == rule.host {
                return .domain
            } else {
                return .subdomain
            }
        } else {
            // Otherwise this is a straight comparison of host+path on both ends.
            // inputs such as "my.great.website" would be compared against
            // "bad.actor.com" and "my.great.website/malware.html"
            // That is we don't want to match a input host to a rule host+path
            // and get a positive value - "sharedHost.com" is malicious
            // because "sharedHost.com/dr.evil/malware" is in the rules.
            let inputDomainAndPath = NSString(string: input.host)
                .appendingPathComponent(input.path)

            let ruleDomainAndPath = NSString(string: rule.host)
                .appendingPathComponent(rule.path)

            return inputDomainAndPath == ruleDomainAndPath ? .specificResource : nil
        }
    }
}
