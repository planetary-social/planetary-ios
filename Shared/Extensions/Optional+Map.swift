//
//  Optional+Map.swift
//  Planetary
//
//  Created by Matthew Lorentz on 3/3/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Optional {
    /// Allows mapping over optional values, applying the transform or returning nil if this Optional is nil.
    func map<T>(_ transform: (WrappedType) -> T) -> T? {
        switch self {
        case .some(let value):
            return transform(value)
        case .none:
            return .none
        }
    }
}
