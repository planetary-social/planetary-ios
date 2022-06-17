//
//  Either.swift
//  Planetary
//
//  Created by Matthew Lorentz on 6/17/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

enum Either<Left, Right> {
    case left(Left), right(Right)
}
