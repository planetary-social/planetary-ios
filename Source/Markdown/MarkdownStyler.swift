//
//  MarkdownStyler.swift
//  Planetary
//
//  Created by Martin Dutra on 4/7/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Down

class MarkdownStyler: DownStyler {

    enum FontStyle {
        case regular
        case compact
        case large
    }

    init(fontStyle: FontStyle) {
        var paragraphStyles = StaticParagraphStyleCollection()
        let headingStyle = NSMutableParagraphStyle()
        let bodyStyle = NSMutableParagraphStyle()
        let codeStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacingBefore = 0
        headingStyle.paragraphSpacing = 0

        bodyStyle.lineSpacing = 0
        if fontStyle == .large {
            bodyStyle.lineHeightMultiple = 0.9
        }
        bodyStyle.paragraphSpacing = 0

        codeStyle.lineSpacing = 0
        codeStyle.paragraphSpacing = 0

        paragraphStyles.body = bodyStyle
        paragraphStyles.heading1 = headingStyle
        paragraphStyles.heading2 = headingStyle
        paragraphStyles.heading3 = headingStyle
        paragraphStyles.code = codeStyle

        var listItemOptions = ListItemOptions()
        listItemOptions.maxPrefixDigits = 1
        listItemOptions.spacingAfterPrefix = 4
        listItemOptions.spacingAbove = 2
        listItemOptions.spacingBelow = 4

        var quoteStripeOptions = QuoteStripeOptions()
        quoteStripeOptions.thickness = 1
        quoteStripeOptions.spacingAfter = 0

        var thematicBreakOptions = ThematicBreakOptions()
        thematicBreakOptions.thickness = 1
        thematicBreakOptions.indentation = 0

        var codeBlockOptions = CodeBlockOptions()
        codeBlockOptions.containerInset = 0

        let downStylerConfiguration = DownStylerConfiguration(
            fonts: MarkdownStyler.fontCollection(fontStyle: fontStyle),
            colors: MarkdownStyler.colorCollection,
            paragraphStyles: paragraphStyles,
            listItemOptions: listItemOptions,
            quoteStripeOptions: quoteStripeOptions,
            thematicBreakOptions: thematicBreakOptions,
            codeBlockOptions: codeBlockOptions
        )

        super.init(configuration: downStylerConfiguration)
    }

    static func fontCollection(fontStyle: FontStyle) -> FontCollection {
        var body: UIFont.TextStyle
        var heading1: UIFont.TextStyle
        var heading2: UIFont.TextStyle
        var heading3: UIFont.TextStyle
        switch fontStyle {
        case .regular:
            body = .body
            heading1 = .title3
            heading2 = .headline
            heading3 = .subheadline
        case .compact:
            body = .body
            heading1 = .body
            heading2 = .body
            heading3 = .body
        case .large:
            body = .title3
            heading1 = .title3
            heading2 = .title3
            heading3 = .title3
        }
        var fonts = StaticFontCollection()
        fonts.body = UIFont.preferredFont(forTextStyle: body)
        switch fontStyle {
        case .regular:
            fonts.heading1 = UIFont.preferredFont(forTextStyle: heading1)
            fonts.heading2 = UIFont.preferredFont(forTextStyle: heading2)
            fonts.heading3 = UIFont.preferredFont(forTextStyle: heading3)
        case .compact, .large:
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: heading1)
            if let descriptor = descriptor.withSymbolicTraits(.traitBold) {
                fonts.heading1 = UIFont(descriptor: descriptor, size: 0)
                fonts.heading2 = UIFont(descriptor: descriptor, size: 0)
                fonts.heading3 = UIFont(descriptor: descriptor, size: 0)
            } else {
                fonts.heading1 = UIFont.preferredFont(forTextStyle: heading1)
                fonts.heading2 = UIFont.preferredFont(forTextStyle: heading2)
                fonts.heading3 = UIFont.preferredFont(forTextStyle: heading3)
            }
        }

        if let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: body).withDesign(.monospaced) {
            fonts.code = UIFont(descriptor: descriptor, size: 0)
            fonts.listItemPrefix = UIFont(descriptor: descriptor, size: 0)
        } else {
            fonts.code = UIFont.preferredFont(forTextStyle: body)
            fonts.listItemPrefix = UIFont.preferredFont(forTextStyle: body)
        }
        return fonts
    }

    static var colorCollection: ColorCollection {
        var colors = StaticColorCollection()
        colors.body = UIColor.primaryTxt
        colors.heading1 = UIColor.primaryTxt
        colors.heading2 = UIColor.primaryTxt
        colors.heading3 = UIColor.primaryTxt
        colors.code = UIColor.secondaryTxt
        colors.link = UIColor.accentTxt
        colors.listItemPrefix = UIColor.accentTxt
        colors.quote = UIColor.secondaryTxt
        colors.quoteStripe = UIColor.secondaryTxt
        colors.thematicBreak = UIColor.accentTxt
        return colors
    }

    override func style(text string: NSMutableAttributedString) {
        super.style(text: string)
        string.addAttributes([.kern: UIFont.post.body.kerning(6)])
    }
    
    func style(seeMore string: NSMutableAttributedString) {
        self.style(text: string)
    }
}
