//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

// A swifty wrapper around `NSCache` to avoid casting/wrapping when a regular NSCache is used.
final class Cache<Key: Hashable, Value> {
    
    // keys are wrapped
    private final class WrappedKey: NSObject {
        let key: Key

        init(_ key: Key) { self.key = key }
        
        override var hash: Int { return key.hashValue }

        override func isEqual(_ object: Any?) -> Bool {
            guard let value = object as? WrappedKey else { return false }
            return value.key == key
        }
    }
    
    // values are wrapped
    private final class WrappedValue {
        let value: Value
        init(_ value: Value) { self.value = value }
    }
    
    // Internal NSCache used for storage.
    private let storage = NSCache<WrappedKey, WrappedValue>()
    
    func set(value: Value?, forKey key: Key) {
        if let value = value {
            storage.setObject(WrappedValue(value), forKey: WrappedKey(key))
        } else {
            self.removeValue(forKey: key)
        }
    }

    func value(forKey key: Key) -> Value? {
        return storage.object(forKey: WrappedKey(key))?.value
    }

    func removeValue(forKey key: Key) {
        storage.removeObject(forKey: WrappedKey(key))
    }
    
    func reset() {
        storage.removeAllObjects()
    }
    
    subscript(key: Key) -> Value? {
        get { return self.value(forKey: key) }
        set { self.set(value: newValue, forKey: key) }
    }
}


