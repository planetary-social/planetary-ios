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
    
    /// This function can be used to `await` results from a `Publisher` in an XCTest.
    ///
    /// This is useful when you want to  assert that a publisher publishes specific values. This function is async
    /// itself so that it can subscribe to the publisher on a background thread. Then the returned Task will wait for
    /// the publisher to complete before returning.
    ///
    /// Example usage:
    /// ```
    /// let observer = await makeAwaitable(publisher: sut.$publisher.collectNext())
    /// functionThatCausesValuesToBePublished()
    /// let publishedResults = try await observer.result.get()
    /// ```
    ///
    /// - Parameter publisher: the publisher you want to wait on.
    /// - Parameter timeout: the number of seconds the function will wait for the publisher before failing the test.
    /// - Returns: A task that will return with the published object or an error.
    func makeAwaitable<T: Publisher>(
        publisher: T,
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

public struct TimeoutError: Error {}
