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

    init() {
        var paragraphStyles = StaticParagraphStyleCollection()
        let headingStyle = NSMutableParagraphStyle()
        let bodyStyle = NSMutableParagraphStyle()
        let codeStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacingBefore = 0
        headingStyle.paragraphSpacing = 0

        bodyStyle.lineSpacing = 0
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
            fonts: MarkdownStyler.fontCollection,
            colors: MarkdownStyler.colorCollection,
            paragraphStyles: paragraphStyles,
            listItemOptions: listItemOptions,
            quoteStripeOptions: quoteStripeOptions,
            thematicBreakOptions: thematicBreakOptions,
            codeBlockOptions: codeBlockOptions
        )

        super.init(configuration: downStylerConfiguration)
    }

    init(small: Bool) {
        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacingBefore = small ? 4 : 16
        headingStyle.paragraphSpacing = small ? 4 : 8
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 1
        bodyStyle.paragraphSpacing = small ? 8 : 12
        let codeStyle = NSMutableParagraphStyle()
        codeStyle.lineSpacing = small ? 0 : 1
        codeStyle.paragraphSpacing = 8

        var paragraphStyles = StaticParagraphStyleCollection()
        paragraphStyles.body = bodyStyle
        paragraphStyles.heading1 = headingStyle
        paragraphStyles.heading2 = headingStyle
        paragraphStyles.heading3 = headingStyle
        paragraphStyles.code = codeStyle
        
        var listItemOptions = ListItemOptions()
        listItemOptions.maxPrefixDigits = small ? 1 : 2
        listItemOptions.spacingAfterPrefix = small ? 4 : 8
        listItemOptions.spacingAbove = small ? 2 : 8
        listItemOptions.spacingBelow = small ? 4 : 8

        var quoteStripeOptions = QuoteStripeOptions()
        quoteStripeOptions.thickness = small ? 1 : 2
        quoteStripeOptions.spacingAfter = small ? 4 : 8

        var thematicBreakOptions = ThematicBreakOptions()
        thematicBreakOptions.thickness = 1
        thematicBreakOptions.indentation = 0
        
        var codeBlockOptions = CodeBlockOptions()
        codeBlockOptions.containerInset = small ? 4 : 8

        let downStylerConfiguration = DownStylerConfiguration(
            fonts: MarkdownStyler.fontCollection(small: small),
            colors: MarkdownStyler.collorCollection(small: small),
            paragraphStyles: paragraphStyles,
            listItemOptions: listItemOptions,
            quoteStripeOptions: quoteStripeOptions,
            thematicBreakOptions: thematicBreakOptions,
            codeBlockOptions: codeBlockOptions
        )
        
        super.init(configuration: downStylerConfiguration)
    }

    static var fontCollection: FontCollection {
        var fonts = StaticFontCollection()
        fonts.body = UIFont.preferredFont(forTextStyle: .body)
        fonts.heading1 = UIFont.preferredFont(forTextStyle: .title3)
        fonts.heading2 = UIFont.preferredFont(forTextStyle: .headline)
        fonts.heading3 = UIFont.preferredFont(forTextStyle: .headline)
        if let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(.monospaced) {
            fonts.code = UIFont(descriptor: descriptor, size: 0)
            fonts.listItemPrefix = UIFont(descriptor: descriptor, size: 0)
        } else {
            fonts.code = UIFont.preferredFont(forTextStyle: .body)
            fonts.listItemPrefix = UIFont.preferredFont(forTextStyle: .body)
        }
        return fonts
    }

    static func fontCollection(small: Bool) -> FontCollection {
        var fonts = StaticFontCollection()
        fonts.body = small ? UIFont.smallPost.body : UIFont.post.body
        fonts.heading1 = small ? UIFont.smallPost.heading1 : UIFont.post.heading1
        fonts.heading2 = small ? UIFont.smallPost.heading2 : UIFont.post.heading2
        fonts.heading3 = small ? UIFont.smallPost.heading3 : UIFont.post.heading3
        fonts.code = small ? UIFont.smallPost.code : UIFont.post.code
        fonts.listItemPrefix = small ? UIFont.smallPost.listItemPrefix : UIFont.post.listItemPrefix
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

    static func collorCollection(small: Bool) -> ColorCollection {
        var colors = StaticColorCollection()
        colors.body = UIColor.text.default
        colors.heading1 = UIColor.secondaryText
        colors.heading2 = UIColor.secondaryText
        colors.heading3 = UIColor.secondaryText
        colors.code = UIColor.secondaryText
        colors.link = UIColor.tint.default
        colors.listItemPrefix = UIColor.tint.default
        colors.quote = UIColor.secondaryText
        colors.quoteStripe = UIColor.secondaryText
        colors.thematicBreak = UIColor.tint.default
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
