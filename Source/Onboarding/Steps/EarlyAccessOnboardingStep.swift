//
//  EarlyAccessOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/17/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class EarlyAccessOnboardingStep: OnboardingStep {

    init() {
        super.init(.earlyAccess)
    }

    override func customizeView() {
        self.view.hintLabel.text = Localized.Onboarding.earlyAccess.text
        self.view.primaryButton.setText(.iUnderstand)
    }
}
