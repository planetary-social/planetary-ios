//
//  BenefitsOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/17/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Support

class BenefitsOnboardingStep: OnboardingStep {

    init() {
        super.init(.benefits)
    }

    override func customizeView() {
        let text = try! NSMutableAttributedString(
            markdown: Text.Onboarding.benefits.text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
        text.addFontAttribute((self.view.hintLabel.font!), colorAttribute: UIColor.menuUnselectedItemText)
        text.addLinkAttribute(
            value: SupportArticle.whatIsPlanetary.rawValue,
            to: Text.Onboarding.findOutMore.text
        )
        text.addParagraphAlignLeft()
        let centerStyle = NSMutableParagraphStyle()
        centerStyle.alignment = .center
        text.addAttributes([.paragraphStyle: centerStyle], to: Text.Onboarding.findOutMore.text)
        self.view.textView.isEditable = false
        self.view.textView.attributedText = text
        self.view.textView.delegate = self
        self.view.textView.layer.borderWidth = 0
        self.view.textView.isScrollEnabled = false
        self.view.textView.backgroundColor = .appBackground
        self.view.primaryButton.setText(.thatSoundsGreat)
    }
}

extension BenefitsOnboardingStep: UITextViewDelegate {

    func textView(_ textView: UITextView,
                  shouldInteractWith URL: URL,
                  in characterRange: NSRange,
                  interaction: UITextItemInteraction) -> Bool {
        guard let article = SupportArticle(rawValue: URL.absoluteString) else { return false }
        guard let controller = Support.shared.articleViewController(article) else {
            AppController.shared.alert(
                title: Text.error.text,
                message: Text.Error.supportNotConfigured.text,
                cancelTitle: Text.ok.text
            )
            return false
        }
        let nc = UINavigationController(rootViewController: controller)
        AppController.shared.present(nc, animated: true)
        return false
    }
}
