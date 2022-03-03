//
//  Optional+Map.swift
//  Planetary
//
//  Created by Matthew Lorentz on 3/3/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Optional {
    func map<T>(_ transform: (WrappedType) -> T) -> Optional<T> {
        switch self {
        case .some(let value):
            return transform(value)
        case .none:
            return .none
        }
    }
}
