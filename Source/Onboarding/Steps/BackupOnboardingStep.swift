//
//  BackupOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class BackupOnboardingStep: OnboardingStep {

    init() {
        super.init(.backup)
    }

    override func customizeView() {
        self.view.hintLabel.text = Text.Onboarding.backupHint.text
        self.view.secondaryButton.setText(.notNow)
        self.view.primaryButton.setText(.backUp)
    }

    override func performSecondaryAction(sender button: UIButton) {
        self.next()
    }

    override func performPrimaryAction(sender button: UIButton) {
        self.data.allowedBackup = true
        self.next()
    }
}
