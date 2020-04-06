//
//  ColorCollection.swift
//  Down
//
//  Created by John Nguyen on 27.07.19.
//  Copyright © 2016-2019 Down. All rights reserved.
//

#if !os(watchOS) && !os(Linux)

#if canImport(UIKit)

import UIKit
public typealias DownColor = UIColor

#elseif canImport(AppKit)

import AppKit
public typealias DownColor = NSColor

#endif

public protocol ColorCollection {

    var heading1: DownColor { get }
    var heading2: DownColor { get }
    var heading3: DownColor { get }
    var body: DownColor { get }
    var code: DownColor { get }
    var link: DownColor { get }
    var quote: DownColor { get }
    var quoteStripe: DownColor { get }
    var thematicBreak: DownColor { get }
    var listItemPrefix: DownColor { get }
    var codeBlockBackground: DownColor { get }
}

public struct StaticColorCollection: ColorCollection {

    public var heading1: DownColor
    public var heading2: DownColor
    public var heading3: DownColor
    public var body: DownColor
    public var code: DownColor
    public var link: DownColor
    public var quote: DownColor
    public var quoteStripe: DownColor
    public var thematicBreak: DownColor
    public var listItemPrefix: DownColor
    public var codeBlockBackground: DownColor

    public init(
        heading1: DownColor = .black,
        heading2: DownColor = .black,
        heading3: DownColor = .black,
        body: DownColor = .black,
        code: DownColor = .black,
        link: DownColor = .blue,
        quote: DownColor = .darkGray,
        quoteStripe: DownColor = .darkGray,
        thematicBreak: DownColor = .init(white: 0.9, alpha: 1),
        listItemPrefix: DownColor = .lightGray,
        codeBlockBackground: DownColor = .init(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
    ) {
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
        self.body = body
        self.code = code
        self.link = link
        self.quote = quote
        self.quoteStripe = quoteStripe
        self.thematicBreak = thematicBreak
        self.listItemPrefix = listItemPrefix
        self.codeBlockBackground = codeBlockBackground
    }
}

#endif
