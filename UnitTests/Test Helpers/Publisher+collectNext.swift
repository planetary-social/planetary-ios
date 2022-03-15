//
//  Publisher+collectNext.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Combine

extension Published.Publisher {
    func collectNext(_ count: Int = 1) -> AnyPublisher<[Output], Never> {
        self.dropFirst()
            .collect(count)
            .first()
            .eraseToAnyPublisher()
    }
}

extension AnyPublisher {
    func collectNext(_ count: Int = 1) -> AnyPublisher<[Output], Failure> {
        self.dropFirst()
            .collect(count)
            .first()
            .eraseToAnyPublisher()
    }
}
