//
//  NullMarkdownStyler.swift
//  Planetary
//
//  Created by Martin Dutra on 4/7/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Down

typealias MarkdownStyler = NullMarkdownStyler

/// MarkdownStyler suitable for use with unit or API test targets.
class NullMarkdownStyler: DownStyler {
    
    init(small: Bool = false) {}
}
