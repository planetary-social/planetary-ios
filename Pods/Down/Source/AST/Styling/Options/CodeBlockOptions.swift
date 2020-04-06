//
//  CodeBlockOptions.swift
//  Down
//
//  Created by John Nguyen on 12.08.19.
//  Copyright © 2016-2019 Down. All rights reserved.
//

#if !os(watchOS) && !os(Linux)

#if canImport(UIKit)

import UIKit

#elseif canImport(AppKit)

import AppKit

#endif

public struct CodeBlockOptions {

    public var containerInset: CGFloat

    public init(containerInset: CGFloat = 8) {
        self.containerInset = containerInset
    }
}

#endif
