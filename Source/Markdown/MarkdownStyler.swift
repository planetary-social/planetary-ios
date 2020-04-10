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
        fonts.body = UIFont.post.body
        fonts.heading1 = UIFont.post.heading1
        fonts.heading2 = UIFont.post.heading2
        fonts.heading3 = UIFont.post.heading3
        fonts.code = UIFont.post.code
        fonts.listItemPrefix = UIFont.post.listItemPrefix
        
        var colors = StaticColorCollection()
        colors.body = UIColor.text.default
        colors.heading1 = UIColor.text.default
        colors.heading2 = UIColor.text.default
        colors.heading3 = UIColor.text.default
        colors.code = UIColor.text.default
        colors.link = UIColor.tint.default
        colors.listItemPrefix = UIColor.tint.default
        colors.quote = UIColor.text.default
        colors.quoteStripe = UIColor.text.default
        colors.thematicBreak = UIColor.tint.default
        
        var paragraphStyles = StaticParagraphStyleCollection()
        let headingStyle = NSMutableParagraphStyle()
        let bodyStyle = NSMutableParagraphStyle()
        let codeStyle = NSMutableParagraphStyle()
        
        headingStyle.paragraphSpacingBefore = 8
        headingStyle.paragraphSpacing = 8
        
        bodyStyle.lineSpacing = 1
        bodyStyle.paragraphSpacing = 2
        
        codeStyle.lineSpacing = 1
        codeStyle.paragraphSpacing = 2
        
        paragraphStyles.body = bodyStyle
        paragraphStyles.heading1 = headingStyle
        paragraphStyles.heading2 = headingStyle
        paragraphStyles.heading3 = headingStyle
        paragraphStyles.code = codeStyle
        
        var listItemOptions = ListItemOptions()
        listItemOptions.maxPrefixDigits = 2
        listItemOptions.spacingAfterPrefix = 8
        listItemOptions.spacingAbove = 4
        listItemOptions.spacingBelow = 8
        
        var quoteStripeOptions = QuoteStripeOptions()
        quoteStripeOptions.thickness = 2
        quoteStripeOptions.spacingAfter = 8
        
        var thematicBreakOptions = ThematicBreakOptions()
        thematicBreakOptions.thickness = 1
        thematicBreakOptions.indentation = 0
        
        var codeBlockOptions = CodeBlockOptions()
        codeBlockOptions.containerInset = 8

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
