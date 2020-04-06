//
//  ThematicBreakOptions.swift
//  Down
//
//  Created by John Nguyen on 04.08.19.
//  Copyright © 2016-2019 Down. All rights reserved.
//

#if !os(watchOS) && !os(Linux)

#if canImport(UIKit)

import UIKit

#elseif canImport(AppKit)

import AppKit

#endif

public struct ThematicBreakOptions {

    public var thickness: CGFloat
    public var indentation: CGFloat

    public init(thickness: CGFloat = 1, indentation: CGFloat = 0) {
        self.thickness = thickness
        self.indentation = indentation
    }
}

#endif
