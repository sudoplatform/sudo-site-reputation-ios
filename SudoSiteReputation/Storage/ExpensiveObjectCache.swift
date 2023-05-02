//
// Copyright © 2020 Anonyome Labs, Inc. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
//
import Foundation

// A control structure that caches the result of an expensive operation.
// This provides a simple wrapper around making multiple async calls
// and only performing the remote work once.
actor ExpensiveObjectCache<ResultType> {
    
    /// If we have knoweldge about data in the cache
    /// its either a cached result, or an in-flight operation to fetch results.
    enum ResultState {
        case cached(ResultType)
        case task(Task<ResultType, Error>)
    }
    
    /// a cache holding data previously fetched, or the request servicing that data.
    private let cache = Cache<String, ResultState>()
    
    /// Get expensive data. Data fetched by the data provider is cached using the provided key.
    /// - parameter key: Key used to cache and lookup data
    /// - parameter dataProvider: an async function that performs some expensive computation, e.g. network request.
    /// - returns: The data requested or the error thrown by the data provider function.
    func get(key: String, dataProvider: @escaping (() async throws -> ResultType)) async throws -> ResultType {
        guard let existing = cache[key] else {
            // create a task and cache the request
            let fetchTask = Task { try await dataProvider() }
            cache[key] = .task(fetchTask)
            
            // wait for the value to come back and change the result in the cache before returning
            let asyncValue = try await fetchTask.value
            cache[key] = .cached(asyncValue)
            return asyncValue
        }
        
        switch existing {
        case .cached(let value):
            // if cached return the value
            return value
        case .task(let existingTask):
            // If an existing task exists await the value.
            // This case is replaced with .cached by the original task.
            return try await existingTask.value
        }
    }
    
    /// Clears all entries from the cache. In-flight data requests will continue and may add entries after the cache is cleared.
    func reset() {
        self.cache.reset()
    }
}
