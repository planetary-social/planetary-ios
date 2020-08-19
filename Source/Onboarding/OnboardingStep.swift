//
//  OnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/15/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

protocol OnboardingStepDelegate: class {

    func step(_ step: OnboardingStep, next: OnboardingStep.Name?)
    func step(_ step: OnboardingStep, back: OnboardingStep.Name?)
}

// TODO either this class or context but not both
class OnboardingStepData {
    var allowedBackup = false
    var allowedContacts = false
    var birthdate: Date? = nil
    var bio: String? = nil
    var code: String? = nil
    var context: Onboarding.Context? = nil
    var following: [Identity] = []
    var image: UIImage? = nil
    var joinedDirectory = false
    var publicWebHosting = false
    var name: String? = nil
    var phone: String? = nil
    var simulated = false
}

class OnboardingStep: NSObject {
    enum Name: String {
        case backup
        case benefits
        case birthday
        case bio
        case contacts
        case directory
        case done
        case earlyAccess
        case join
        case name
        case phone
        case phoneVerify
        case photo
        case photoConfirm
        case resume
        case start

        var title: Text.Onboarding.StepTitle {
            switch self {
                case .backup: return .backup
                case .benefits: return .benefits
                case .birthday: return .birthday
                case .bio: return .bio
                case .contacts: return .contacts
                case .directory: return .directory
                case .done: return .done
                case .earlyAccess: return .earlyAccess
                case .join: return .join
                case .name: return .name
                case .phone: return .phone
                case .phoneVerify: return .phoneVerify
                case .photo: return .photo
                case .photoConfirm: return .photoConfirm
                case .resume: return .resume
                case .start: return .start
            }
        }
    }

    let name: Name

    /// Default values, should be set the OnboardingViewController
    /// before presenting the step to carry values forward.
    var data = OnboardingStepData()

    // The view representing the step, which is defaulted to show
    // the title and the primary and secondary buttons.  Step subclasses
    // should hide/show buttons and fields as necessary by overriding
    // customizeView().
    internal lazy var view: OnboardingStepView = {
        let view = OnboardingStepView(buttonStyle: self.buttonStyle)
        view.titleLabel.text = self.name.title.text
        return view
    }()

    /// Delegate, likely the OnboardingViewController
    weak var delegate: OnboardingStepDelegate?

    let buttonStyle: OnboardingStepView.ButtonStyle

    var showsNavigationBar = false

    init(_ name: Name, buttonStyle: OnboardingStepView.ButtonStyle = .verticalStack) {
        self.name = name
        self.buttonStyle = buttonStyle
        super.init()
        self.addActions()
    }

    /// Called before the step's view is presented, but after init().
    func customizeController(controller: ContentViewController) {
        // subclasses should override to modify the behavior of the controller
    }

    /// Called before the step's view is presented, but after init().
    func customizeView() {
        // subclasses should override to add their own views or customize text
    }

    // MARK: Internal actions

    private func addActions() {

        self.view.textFieldValueDidChange = {
            [unowned self] textField in
            self.textFieldValueDidChange(textField)
        }

        self.view.secondaryButtonTouchUpInside = {
            [unowned self] button in
            self.secondary()
        }

        self.view.primaryButtonTouchUpInside = {
            [unowned self] button in
            self.primary()
        }
    }

    // MARK: Actions to override

    /// This is explicitly final because there should be no
    /// changes to when the step is tracked by Analytics.shared.
    final func track() {
        Analytics.shared.trackOnboarding(self.name)
    }

    func willStart() {
        // subclasses should override to do work before the step is visible
    }

    func didStart() {
        // subclasses should override to do work when the step is visible
    }

    func textFieldValueDidChange(_ textField: UITextField) {
        // subclasses should override to store value into self.data
        // or to validate input and change button state
    }

    func textViewValueDidChange(_ textView: UITextView) {
        // subclasses should override to store value into self.data
        // or to validate input and change button state
    }

    func secondary() {
        // subclasses should override as there is no default implementation
    }

    func primary() {
        self.delegate?.step(self, next: nil)
    }

    // MARK: Navigation

    func next(_ step: Name? = nil) {
        self.delegate?.step(self, next: step)
    }

    func back(_ step: Name? = nil) {
        self.delegate?.step(self, back: step)
    }
}
