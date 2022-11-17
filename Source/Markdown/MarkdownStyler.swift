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
        var fonts = StaticFontCollection()
        fonts.body = UIFont.preferredFont(forTextStyle: .body)
        fonts.heading1 = UIFont.preferredFont(forTextStyle: .title3)
        fonts.heading2 = UIFont.preferredFont(forTextStyle: .headline)
        fonts.heading3 = UIFont.preferredFont(forTextStyle: .subheadline)
        if let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(.monospaced) {
            fonts.code = UIFont(descriptor: descriptor, size: 0)
            fonts.listItemPrefix = UIFont(descriptor: descriptor, size: 0)
        } else {
            fonts.code = UIFont.preferredFont(forTextStyle: .body)
            fonts.listItemPrefix = UIFont.preferredFont(forTextStyle: .body)
        }

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
            fonts: fonts,
            colors: colors,
            paragraphStyles: paragraphStyles,
            listItemOptions: listItemOptions,
            quoteStripeOptions: quoteStripeOptions,
            thematicBreakOptions: thematicBreakOptions,
            codeBlockOptions: codeBlockOptions
        )

        super.init(configuration: downStylerConfiguration)
    }

    init(small: Bool) {
        var fonts = StaticFontCollection()
        if small {
            fonts.body = UIFont.smallPost.body
            fonts.heading1 = UIFont.smallPost.heading1
            fonts.heading2 = UIFont.smallPost.heading2
            fonts.heading3 = UIFont.smallPost.heading3
            fonts.code = UIFont.smallPost.code
            fonts.listItemPrefix = UIFont.smallPost.listItemPrefix
        } else {
            fonts.body = UIFont.post.body
            fonts.heading1 = UIFont.post.heading1
            fonts.heading2 = UIFont.post.heading2
            fonts.heading3 = UIFont.post.heading3
            fonts.code = UIFont.post.code
            fonts.listItemPrefix = UIFont.post.listItemPrefix
        }
        
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
        
        var paragraphStyles = StaticParagraphStyleCollection()
        let headingStyle = NSMutableParagraphStyle()
        let bodyStyle = NSMutableParagraphStyle()
        let codeStyle = NSMutableParagraphStyle()

        if small {
            headingStyle.paragraphSpacingBefore = 4
            headingStyle.paragraphSpacing = 4

            bodyStyle.lineSpacing = 1
            bodyStyle.paragraphSpacing = 8

            codeStyle.lineSpacing = 0
            codeStyle.paragraphSpacing = 8
        } else {
            headingStyle.paragraphSpacingBefore = 16
            headingStyle.paragraphSpacing = 8

            bodyStyle.lineSpacing = 1
            bodyStyle.paragraphSpacing = 12

            codeStyle.lineSpacing = 1
            codeStyle.paragraphSpacing = 8
        }
        
        paragraphStyles.body = bodyStyle
        paragraphStyles.heading1 = headingStyle
        paragraphStyles.heading2 = headingStyle
        paragraphStyles.heading3 = headingStyle
        paragraphStyles.code = codeStyle
        
        var listItemOptions = ListItemOptions()
        if small {
            listItemOptions.maxPrefixDigits = 1
            listItemOptions.spacingAfterPrefix = 4
            listItemOptions.spacingAbove = 2
            listItemOptions.spacingBelow = 4
        } else {
            listItemOptions.maxPrefixDigits = 2
            listItemOptions.spacingAfterPrefix = 8
            listItemOptions.spacingAbove = 8
            listItemOptions.spacingBelow = 8
        }

        var quoteStripeOptions = QuoteStripeOptions()
        if small {
            quoteStripeOptions.thickness = 1
            quoteStripeOptions.spacingAfter = 4
        } else {
            quoteStripeOptions.thickness = 2
            quoteStripeOptions.spacingAfter = 8
        }

        var thematicBreakOptions = ThematicBreakOptions()
        thematicBreakOptions.thickness = 1
        thematicBreakOptions.indentation = 0
        
        var codeBlockOptions = CodeBlockOptions()
        if small {
            codeBlockOptions.containerInset = 4
        } else {
            codeBlockOptions.containerInset = 8
        }

        let downStylerConfiguration = DownStylerConfiguration(fonts: fonts,
                                                              colors: colors,
                                                              paragraphStyles: paragraphStyles,
                                                              listItemOptions: listItemOptions,
                                                              quoteStripeOptions: quoteStripeOptions,
                                                              thematicBreakOptions: thematicBreakOptions,
                                                              codeBlockOptions: codeBlockOptions)
        
        super.init(configuration: downStylerConfiguration)
    }
    
    override func style(text str: NSMutableAttributedString) {
        super.style(text: str)
        str.addAttributes([.kern: UIFont.post.body.kerning(6)])
    }
    
    func style(seeMore str: NSMutableAttributedString) {
        self.style(text: str)
    }
}
