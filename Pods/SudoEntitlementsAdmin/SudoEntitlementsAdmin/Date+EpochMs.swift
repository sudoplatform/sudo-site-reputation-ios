//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

extension Date {

    /// Instantiates a Date object using milliseconds since Epoch.
    ///
    /// - Parameter millisecondsSinceEpoch: milliseconds since Epoch.
    init(millisecondsSinceEpoch: Double) {
        self.init(timeIntervalSince1970: millisecondsSinceEpoch / 1000)
    }

}
