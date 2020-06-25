//
//  BioOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class BioOnboardingStep: OnboardingStep, UITextViewDelegate {

    init() {
        super.init(.bio, buttonStyle: .horizontalStack)
    }

    override func customizeView() {
        self.view.textView.becomeFirstResponder()
        self.view.textView.delegate = self
        self.view.textView.backgroundColor = UIColor.background.default
        self.view.hintLabel.text = Text.Onboarding.bioHint.text
        self.view.secondaryButton.setText(.skip)
        self.view.titleLabelTopConstraint?.constant = UIScreen.main.isShort ? Layout.verticalSpacing : Layout.verticalSpacing * 2
        if UIScreen.main.isShort {
            self.view.textViewTopConstraint?.constant = Layout.verticalSpacing
        }
        self.view.hintLabel.pinBottom(toTopOf: self.view.buttonStack, constant: -Layout.verticalSpacing)
    }

    // Limit the number of characters in the bio.
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return textView.text.count + (text.count - range.length) <= 140
    }

    func textViewDidChange(_ textView: UITextView) {
        self.data.bio = textView.text
    }

    override func secondary() {
        self.next()
    }

    override func primary() {

        // not requiring any bio right now
        guard let bio = self.data.bio else {
            self.next()
            return
        }

        // SIMULATE ONBOARDING
        if self.data.simulated { self.next(); return }

        guard let context = self.data.context else {
            Log.unexpected(.missingValue, "Was expecting self.data.context, skipping step")
            self.next()
            return
        }

        guard let identity = self.data.context?.about?.identity else {
            Log.unexpected(.missingValue, "Was expecting self.data.context.about.identity, skipping step")
            self.next()
            return
        }

        self.view.lookBusy(disable: self.view.primaryButton)

        let about = About(about: identity, descr: bio)
        context.bot.publish(content: about) {
            [weak self] _, error in
            self?.view.lookReady()
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if error == nil { self?.next() }
        }
    }
}
