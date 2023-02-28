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
        // Bot and API calls
        StartOnboardingStep(),
        BenefitsOnboardingStep(),
        BirthdateOnboardingStep(),
        NameOnboardingStep(),
        PhotoOnboardingStep(),
        PhotoConfirmOnboardingStep(),   // Bot and API calls
        BioOnboardingStep(),            // Bot and API calls
        DoneOnboardingStep(),           // Bot and API calls
        JoinOnboardingStep(),           // Bot and API calls
        RoomsOnboardingStep(),          // Bot and API calls
    ]

    private let resumeSteps = [
        ResumeOnboardingStep(),
        BioOnboardingStep(),            // Bot and API calls
        DoneOnboardingStep(),           // Bot and API calls
        RoomsOnboardingStep(),          // Bot and API calls
    ]

    private var steps: [OnboardingStep] = []

    private var currentStep: OnboardingStep? {
        steps[safe: stepIndex]
    }

    private var stepData = OnboardingStepData()

    init(status: Onboarding.Status, simulate: Bool = false) {
        assert(status != .completed)
        super.init(nibName: nil, bundle: nil)

        self.stepData.simulated = simulate
        if simulate { Log.info("SIMULATING ONBOARDING") }

        steps = status == .started ? resumeSteps : startSteps
        pushViewController(for: steps[0], animated: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        isNavigationBarHidden = true
        view.backgroundColor = .appBackground
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Onboarding")
        Analytics.shared.trackDidShowScreen(screenName: "onboarding")
        forceNavigationControllerDelegateDidShowViewController()
    }

    private func viewController(for step: OnboardingStep) -> ContentViewController {
        step.data = stepData
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
        let controller = viewController(for: step)
        self.pushViewController(controller, animated: animated)
    }

    private func nextStep() {
        self.stepIndex += 1
        guard let step = steps[safe: stepIndex] else {
            self.done()
            return
        }
        self.pushViewController(for: step)
    }

    /// Looks through the steps, starting from the current index, to find
    /// a step with the specified name.  Then, a matching controller is put
    /// on the stack.
    private func next(to step: OnboardingStep.Name) {
        for index in stepIndex ..< steps.count {
            if steps[index].name == step {
                stepIndex = index
                pushViewController(for: steps[index])
                return
            }
        }
    }

    private func previousStep() {
        guard self.stepIndex > 0 else {
            return
        }
        stepIndex -= 1
        popViewController(animated: true)
    }

    private func done() {
        if let identity = stepData.context?.identity {
            Onboarding.set(status: .completed, for: identity)
        }
        Analytics.shared.trackOnboardingEnd()
        AppController.shared.showMainViewController(fadeIn: true)
    }

    // MARK: OnboardingStepDelegate

    func step(_ step: OnboardingStep, next forcedNextStep: OnboardingStep.Name?) {
        if let forcedNextStep = forcedNextStep {
            next(to: forcedNextStep)
        } else {
            nextStep()
        }
    }

    func step(_ step: OnboardingStep, back: OnboardingStep.Name?) {
        previousStep()
    }
}

extension OnboardingViewController: UINavigationControllerDelegate {

    /// Workaround for an iOS 13 oddity where UINavigationControllerDelegate.didShow()
    /// is called twice: once when the navigation controller is added to the view hierachy,
    /// then a second time when the top view controller is added to the view hierarchy.
    internal func forceNavigationControllerDelegateDidShowViewController() {
        delegate = self
        if let topViewController = topViewController {
            delegate?.navigationController?(self, didShow: topViewController, animated: false)
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        guard let currentStep = currentStep else {
            return
        }
        setNavigationBarHidden(!currentStep.showsNavigationBar, animated: false)
        currentStep.willStart()
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        guard let currentStep = currentStep else {
            return
        }
        currentStep.didStart()
        currentStep.track()
    }
}
