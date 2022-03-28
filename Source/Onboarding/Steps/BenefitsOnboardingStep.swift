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
        let text = NSMutableAttributedString(string: Text.Onboarding.benefits.text)
        text.addFontAttribute((self.view.hintLabel.font!), colorAttribute: UIColor.text.default)
        text.addLinkAttribute(value: SupportArticle.whatIsPlanetary.rawValue,
                              to: Text.Onboarding.findOutMore.text)
        text.addParagraphAlignCenter()
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

fileprivate extension NSMutableAttributedString {

    func addParagraphAlignCenter() {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        self.addAttributes([NSAttributedString.Key.paragraphStyle: style])
    }
}
