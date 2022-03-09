//
//  Publisher+Async.swift
//  Planetary
//
//  Created by Matthew Lorentz on 3/2/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Combine

extension Publisher {
    /// A version of `flatMap` that takes an `async` block as it's transform function.
    func asyncFlatMap<T>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (Self.Output) async -> T
    ) -> Publishers.FlatMap<Future<T, Self.Failure>, Self> where Self.Failure == Never {

        return flatMap(maxPublishers: maxPublishers) { (input: Self.Output) -> Future<T, Self.Failure> in
            return Future<T, Self.Failure> { promise in
                Task.detached {
                    let output = await transform(input)
                    promise(.success(output))
                }
            }
        }
    }
}
