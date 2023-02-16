//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Test helper to capture an error from a throwing function.
func captureThrownError(_ closure: (() throws -> Void) ) -> Error? {
    do {
        try closure()
        return nil
    } catch {
        return error
    }
}

/// Test helper to capture an error from an async throwing function.
func captureThrownError(_ closure: (() async throws -> Void) ) async -> Error? {
    do {
        try await closure()
        return nil
    } catch {
        return error
    }
}
