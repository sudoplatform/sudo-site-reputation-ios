//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

struct MaliciousDomainListKey: Equatable {
    let key: String
    let bucket: String
    let eTag: String
}

struct MaliciousDomainList: Codable, Equatable {
    let key: String
    let eTag: String
    let category: String
    let name: String
    let body: Data
}

extension MaliciousDomainList {

    var domains: [String] {
        return String(decoding: body, as: UTF8.self).components(separatedBy: "\n")
    }
}

let slugFromKey = { (key: String) in
    // The service guarantees that the filename component
    // of the key is unique among malicious domain lists.
    key.components(separatedBy: "/").last ?? ""
}

extension MaliciousDomainListKey {
    /// A filename-safe string that is unique among malicious domain lists.
    var slug: String { slugFromKey(key) }
}

extension MaliciousDomainList {
    /// A filename-safe string that is unique among malicious domain lists.
    var slug: String { slugFromKey(key) }
}
