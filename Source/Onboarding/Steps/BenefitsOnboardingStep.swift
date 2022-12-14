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
        let text = (try? NSMutableAttributedString(
            markdown: Localized.Onboarding.benefits.text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? NSMutableAttributedString(string: Localized.Onboarding.benefits.text)
        if let font = view.hintLabel.font {
            text.addFontAttribute(font, colorAttribute: UIColor.menuUnselectedItemText)
        }
        text.addLinkAttribute(
            value: SupportArticle.whatIsPlanetary.rawValue,
            to: Localized.Onboarding.findOutMore.text
        )
        text.addParagraphAlignLeft()
        let centerStyle = NSMutableParagraphStyle()
        centerStyle.alignment = .center
        text.addAttributes([.paragraphStyle: centerStyle], to: Localized.Onboarding.findOutMore.text)
        self.view.textView.isEditable = false
        self.view.textView.attributedText = text
        self.view.textView.delegate = self
        self.view.textView.layer.borderWidth = 0
        self.view.textView.isScrollEnabled = true
        self.view.textView.backgroundColor = .appBackground
        self.view.primaryButton.setText(.thatSoundsGreat)
        view.textView.bottomAnchor.constraint(equalTo: view.primaryButton.topAnchor, constant: -20).isActive = true
    }
}

extension BenefitsOnboardingStep: UITextViewDelegate {

    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        guard let article = SupportArticle(rawValue: URL.absoluteString) else { return false }
        guard let controller = Support.shared.articleViewController(article) else {
            AppController.shared.alert(
                title: Localized.error.text,
                message: Localized.Error.supportNotConfigured.text,
                cancelTitle: Localized.ok.text
            )
            return false
        }
        let navigationController = UINavigationController(rootViewController: controller)
        AppController.shared.present(navigationController, animated: true)
        return false
    }
}
