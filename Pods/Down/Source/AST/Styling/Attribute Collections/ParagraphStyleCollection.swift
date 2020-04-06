//
//  ParagraphStyleCollection.swift
//  Down
//
//  Created by John Nguyen on 27.07.19.
//  Copyright © 2016-2019 Down. All rights reserved.
//

#if !os(watchOS) && !os(Linux)

#if canImport(UIKit)

import UIKit

#elseif canImport(AppKit)

import AppKit

#endif

public protocol ParagraphStyleCollection {

    var heading1: NSParagraphStyle { get }
    var heading2: NSParagraphStyle { get }
    var heading3: NSParagraphStyle { get }
    var body: NSParagraphStyle { get }
    var code: NSParagraphStyle { get }
}

public struct StaticParagraphStyleCollection: ParagraphStyleCollection {

    public var heading1: NSParagraphStyle
    public var heading2: NSParagraphStyle
    public var heading3: NSParagraphStyle
    public var body: NSParagraphStyle
    public var code: NSParagraphStyle

    public init() {
        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacing = 8

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.paragraphSpacingBefore = 8
        bodyStyle.paragraphSpacing = 8
        bodyStyle.lineSpacing = 8

        let codeStyle = NSMutableParagraphStyle()
        codeStyle.paragraphSpacingBefore = 8
        codeStyle.paragraphSpacing = 8

        heading1 = headingStyle
        heading2 = headingStyle
        heading3 = headingStyle
        body = bodyStyle
        code = codeStyle
    }
}

#endif
