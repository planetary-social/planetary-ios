//
//  OnboardingViewController.swift
//  FBTT
//
//  Created by Christoph on 7/9/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting

class OnboardingViewController: UINavigationController, OnboardingStepDelegate {

    private var stepIndex = 0

    private let startSteps = [
        StartOnboardingStep(),
        BenefitsOnboardingStep(),
        BirthdateOnboardingStep(),
        NameOnboardingStep(),
        // disabling phone verification due to twillio bug
//        PhoneOnboardingStep(),
//        PhoneVerifyOnboardingStep(),
        JoinOnboardingStep(),           // Bot and API calls
        // disabled until we work on these again
//        BackupOnboardingStep(),
//        ContactsOnboardingStep(),
//        DirectoryOnboardingStep(),      // Bot and API calls
        PhotoOnboardingStep(),
        PhotoConfirmOnboardingStep(),   // Bot and API calls
        BioOnboardingStep(),            // Bot and API calls
        DoneOnboardingStep(),           // Bot and API calls
    ]

    private let resumeSteps = [
        ResumeOnboardingStep(),
        // DirectoryOnboardingStep(),      // Bot and API calls
        // PhotoOnboardingStep(),
        // PhotoConfirmOnboardingStep(),   // Bot and API calls
        BioOnboardingStep(),            // Bot and API calls
        DoneOnboardingStep(),           // Bot and API calls
    ]

    // TODO need to set in init()
    private var steps: [OnboardingStep] = []

    private var currentStep: OnboardingStep {
            self.steps[self.stepIndex]
    }

    private var stepData = OnboardingStepData()

    // TODO does status need to be passed in?
    // TODO guard not completed?
    init(status: Onboarding.Status, simulate: Bool = false) {

        assert(status != .completed)
        super.init(nibName: nil, bundle: nil)

        self.stepData.simulated = simulate
        if simulate { Log.info("SIMULATING ONBOARDING") }

        self.steps = status == .started ? self.resumeSteps : self.startSteps
        self.pushViewController(for: self.steps[0], animated: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.isNavigationBarHidden = true
        self.view.backgroundColor = .appBackground
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Onboarding")
        Analytics.shared.trackDidShowScreen(screenName: "onboarding")
        self.forceNavigationControllerDelegateDidShowViewController()
    }

    private func viewController(for step: OnboardingStep) -> ContentViewController {
        step.data = self.stepData
        step.customizeView()
        step.delegate = self
        let controller = ContentViewController(scrollable: true)

        controller.isKeyboardHandlingEnabled = true
        controller.navigationItem.title = step.name.title.text
        controller.view?.backgroundColor = .appBackground
        Layout.fill(view: controller.contentView, with: step.view)
        controller.contentView.heightAnchor.constraint(
            greaterThanOrEqualTo: controller.scrollView.heightAnchor
        ).isActive = true

        step.customizeController(controller: controller)

        return controller
    }

    /// This will continually stack view controllers.  Likely this is not an issue
    /// but if there are many, or they don't release, then it could cause memory
    /// pressure.
    private func pushViewController(for step: OnboardingStep, animated: Bool = true) {
        let controller = self.viewController(for: step)
        self.pushViewController(controller, animated: animated)
    }

    private func nextStep() {
        self.stepIndex += 1
        guard let step = self.steps[safe: self.stepIndex] else { self.done(); return }
        self.pushViewController(for: step)
    }

    /// Looks through the steps, starting from the current index, to find
    /// a step with the specified name.  Then, a matching controller is put
    /// on the stack.
    private func next(to step: OnboardingStep.Name) {
        for index in self.stepIndex..<self.steps.count {
            if self.steps[index].name == step {
                self.stepIndex = index
                self.pushViewController(for: self.steps[index])
                return
            }
        }
    }

    private func previousStep() {
        guard self.stepIndex > 0 else { return }
        self.stepIndex -= 1
        self.popViewController(animated: true)
    }

    private func done() {
        // AppController.shared.showDirectoryViewController()
        AppController.shared.showMainViewController()
    }

    // MARK: OnboardingStepDelegate

    func step(_ step: OnboardingStep, next: OnboardingStep.Name?) {
        if let next = next { self.next(to: next) } else { self.nextStep() }
    }

    func step(_ step: OnboardingStep, back: OnboardingStep.Name?) {
        // TODO figure out current index
        // TODO look back in stack for index of matching name
        // TODO self.popToViewController()
        self.previousStep()
    }
}

extension OnboardingViewController: UINavigationControllerDelegate {

    /// Workaround for an iOS 13 oddity where UINavigationControllerDelegate.didShow()
    /// is called twice: once when the navigation controller is added to the view hierachy,
    /// then a second time when the top view controller is added to the view hierarchy.
    internal func forceNavigationControllerDelegateDidShowViewController() {
        self.delegate = self
        self.delegate?.navigationController?(self, didShow: self.topViewController!, animated: false)
    }

    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated: Bool) {
        self.setNavigationBarHidden(!currentStep.showsNavigationBar, animated: false)
        self.currentStep.willStart()
    }

    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        self.currentStep.didStart()
        self.currentStep.track()
    }
}
