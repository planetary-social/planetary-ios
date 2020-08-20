//
//  AppController.swift
//  FBTT
//
//  Created by Christoph on 1/11/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class AppController: UIViewController {

    static let shared = AppController()
    
    /// Mission Control Center manages missions to stars when launching the app, sending the app
    /// to the background, back to the foreground, and exiting the app
    var missionControlCenter = MissionControlCenter()
    
    /// Queue to handle background operations
    var operationQueue = OperationQueue()
    
    private var didStartDatabaseProcessingObserver: NSObjectProtocol?
    private var didFinishDatabaseProcessingObserver: NSObjectProtocol?
    private var didUpdateDatabaseProgressObserver: NSObjectProtocol?

    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.background.default
        self.addObservers()
    }
    
    deinit {
        removeObservers()
    }

    /// Because controllers are nested and presented when the keyboard is also being presented,
    /// Autolayout may not have had a chance to do its thing.  So, it is forced here to ensure
    /// that the view hierarchy has been sized correctly before presenting.
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        viewControllerToPresent.view.setNeedsLayout()
        viewControllerToPresent.view.layoutIfNeeded()
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    // MARK: Root view controller

    func setRootViewController(_ controller: UIViewController, animated: Bool = true) {
        self.removeRootViewController()
        controller.willMove(toParent: self)
        self.addChild(controller)
        controller.view.frame = self.view.bounds
        self.view.addSubview(controller.view)
        controller.didMove(toParent: self)
    }

    private func removeRootViewController() {
        self.view.subviews.forEach { $0.removeFromSuperview() }
        self.children.forEach { $0.removeFromParent() }
    }

    // MARK: alert/warnings
    func showAlertController(with alert: UIAlertController, animated: Bool = true) {
        let controller = UIViewController()
        self.setRootViewController(controller, animated: animated)
        controller.present(alertController: alert, animated: animated)
    }

    // MARK: Main tab view controller

    func showMainViewController(with controller: UIViewController? = nil, animated: Bool = true) {
        let controller = MainViewController()
        self.setRootViewController(controller, animated: animated)
        self.missionControlCenter.start()
    }

    var mainViewController: MainViewController? {
        return self.children.first as? MainViewController
    }

    // MARK: Onboarding view controller

    func showOnboardingViewController(_ status: Onboarding.Status = .notStarted,
                                      _ simulate: Bool = false,
                                      animated: Bool = true)
    {
        let controller = OnboardingViewController(status: status, simulate: simulate)
        self.setRootViewController(controller, animated: animated)
    }

    // MARK: Menu view controller

    func showMenuViewController(animated: Bool = true) {
        let controller = MenuViewController()
        controller.modalPresentationStyle = .overCurrentContext
        self.mainViewController?.present(controller, animated: false) {
            controller.open()
        }
    }

    // MARK: Settings view controller

    func showSettingsViewController() {
        let nc = UINavigationController(rootViewController: SettingsViewController())
        self.mainViewController?.present(nc, animated: true)
    }
    
    // MARK: Observers
    
    func addObservers() {
        let showProgress = { [weak self] (notification: Notification) -> Void in
            self?.showProgress(statusText: notification.databaseProgressStatus)
            self?.missionControlCenter.pause()
        }
        let updateProgress = { [weak self] (notification: Notification) -> Void in
            guard let percDone = notification.databaseProgressPercentageDone else { return }
            guard let status = notification.databaseProgressStatus else { return }
            self?.updateProgress(perc: percDone, status: status)
        }
        let dismissProgress = { [weak self] (notification: Notification) -> Void in
            self?.hideProgress()
            self?.missionControlCenter.resume()
        }
        removeObservers()
        let notificationCenter = NotificationCenter.default
        didStartDatabaseProcessingObserver = notificationCenter.addObserver(forName: .didStartFSCKRepair,
                                                                    object: nil,
                                                                    queue: .main,
                                                                    using: showProgress)
        didFinishDatabaseProcessingObserver = notificationCenter.addObserver(forName: .didFinishFSCKRepair,
                                                                     object: nil,
                                                                     queue: .main,
                                                                     using: dismissProgress)
        didUpdateDatabaseProgressObserver = notificationCenter.addObserver(forName: .didUpdateFSCKRepair,
                                                                       object: nil,
                                                                       queue: .main,
                                                                       using: updateProgress)
    }
    
    func removeObservers() {
        let notificationCenter = NotificationCenter.default
        if let start = self.didStartDatabaseProcessingObserver {
            notificationCenter.removeObserver(start)
        }
        if let finish = self.didFinishDatabaseProcessingObserver {
            notificationCenter.removeObserver(finish)
        }
        if let progress = self.didUpdateDatabaseProgressObserver {
            notificationCenter.removeObserver(progress)
        }
    }
}
