//
//  OnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/15/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics

protocol OnboardingStepDelegate: AnyObject {

    func step(_ step: OnboardingStep, next: OnboardingStep.Name?)
    func step(_ step: OnboardingStep, back: OnboardingStep.Name?)
}

// TODO either this class or context but not both
class OnboardingStepData {
    var allowedBackup = false
    var allowedContacts = false
    var birthdate: Date?
    var bio: String?
    var code: String?
    var context: Onboarding.Context?
    var following: [Identity] = []
    var image: UIImage?
    var joinedDirectory = false
    var joinPlanetarySystem = false
    var useTestNetwork = false
    var publicWebHosting = false
    var analytics = false
    var followPlanetary = false
    var name: String?
    var phone: String?
    var simulated = false

    var analyticsData: Analytics.OnboardingStepData {
        Analytics.OnboardingStepData(
            allowedBackup: allowedBackup,
            allowedContacts: allowedContacts,
            bio: bio,
            followingCount: following.count,
            hasImage: image != nil,
            joinedDirectory: joinedDirectory,
            joinPlanetarySystem: joinPlanetarySystem,
            useTestNetwork: useTestNetwork,
            publicWebHosting: publicWebHosting,
            analytics: analytics,
            followPlanetary: followPlanetary,
            nameLength: name?.count ?? 0,
            phone: phone,
            simulated: simulated
        )
    }
}

@MainActor class OnboardingStep: NSObject {
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

        var analyticsStep: Analytics.OnboardingStep {
            Analytics.OnboardingStep(rawValue: rawValue) ?? .unknown
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
            self.performSecondaryAction(sender: button)
        }

        self.view.primaryButtonTouchUpInside = {
            [unowned self] button in
            self.performPrimaryAction(sender: button)
        }
    }

    // MARK: Actions to override

    /// This is explicitly final because there should be no
    /// changes to when the step is tracked by Analytics.shared.
    final func track() {
        Analytics.shared.trackOnboarding(self.name.analyticsStep)
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

    func performSecondaryAction(sender button: UIButton) {
        // subclasses should override as there is no default implementation
    }

    func performPrimaryAction(sender button: UIButton) {
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
