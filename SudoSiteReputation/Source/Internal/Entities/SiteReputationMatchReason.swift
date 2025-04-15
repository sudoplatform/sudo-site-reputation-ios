//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

// The reason the site reputation provider determined an input was malicious.
enum SiteReputationMatchReason {

    /// Exact domain match, i.e. "foo.bar.com" == "foo.bar.com"
    case domain

    /// Subdomain match, i.e. does "foo.bar.baz.virus.malwareSite.com" match "malwareSite.com"
    case subdomain

    /// The match was for a specific resource (domain and path),
    /// i.e. "www.badactor.com/virus.exe" matched "www.badactor.com/virus.exe"
    case specificResource
}
