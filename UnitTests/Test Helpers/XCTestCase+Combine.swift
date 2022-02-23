//
//  XCTestCase+Combine.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import XCTest
import Combine

extension XCTestCase {
    func publisherCompletion<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) async -> Task<T.Output, Error> {

        let waitForPublisherTask: Task<T.Output, Error> = Task.detached {
            var cancellables = [AnyCancellable]()
            
            let result: T.Output = try await withCheckedThrowingContinuation { continuation in
                // Set up timeout
                let timeoutTask = Task.detached {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    continuation.resume(with: .failure(TimeoutError()))
                }
                
                var result: Result<T.Output, Error>?

                publisher
                    .sink(
                        receiveCompletion: { completion in
                            timeoutTask.cancel()
                            
                            switch completion {
                            case .failure(let error):
                                result = .failure(error)
                            case .finished:
                                break
                            }
                                                        
                            do {
                                let unwrappedResult = try XCTUnwrap(
                                    result,
                                    "Awaited publisher did not produce any output",
                                    file: file,
                                    line: line
                                )
                                continuation.resume(with: unwrappedResult)
                                
                            } catch {
                                continuation.resume(with: .failure(error))
                            }
                            
                        },
                        receiveValue: { value in
                            result = .success(value)
                        }
                    )
                    .store(in: &cancellables)
                
                

            }
            
            cancellables.forEach { $0.cancel() }
            return result
        }
        
        await Task.yield()
        
        return waitForPublisherTask
    }
}

// https://github.com/alexito4/Baggins/blob/main/Sources/Baggins/Concurrency.swift

public func withTimeout<R>(
    _ seconds: UInt64,
    _ work: @escaping () async throws -> R
) async throws -> R {
    try await firstOf {
        try await work()
    } or: {
        try? await Task.sleep(seconds)
        throw TimeoutError()
    }
}

public struct TimeoutError: Error {}

public func firstOf<R>(
    _ f1: @escaping () async throws -> R,
    or f2: @escaping () async throws -> R
) async throws -> R {
    // All the cancellation checks I feel they shouldn't be necessary.
    // But I haven't been able to write a unit test that triggers the guard of
    // `addTaskUnlessCancelled`...
    try Task.checkCancellation()
    return try await withThrowingTaskGroup(of: R.self) { group in
        try Task.checkCancellation()
        guard group.addTaskUnlessCancelled(operation: { try await f1() }) else {
            throw CancellationError()
        }
        guard group.addTaskUnlessCancelled(operation: { try await f2() }) else {
            group.cancelAll()
            throw CancellationError()
        }
        guard let first = try await group.next() else {
            fatalError()
        }
        group.cancelAll()
        return first
    }
}
