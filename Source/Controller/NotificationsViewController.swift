//
//  NotificationsViewController.swift
//  FBTT
//
//  Created by Christoph on 6/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting
import SwiftUI

class NotificationsViewController: ContentViewController, HelpDrawerViewControllerHost {

    private let dataSource = NotificationsTableViewDataSource()
    private lazy var delegate = NotificationsTableViewDelegate(on: self)

    /// The last time we loaded the reports from the database or we checked if there are new reports to show
    private var lastTimeNewReportsUpdatesWasChecked = Date()

    private lazy var newPostBarButtonItem: UIBarButtonItem = {
        let image = UIImage.navIconWrite
        let item = UIBarButtonItem(
            image: image,
            style: .plain,
            target: self,
            action: #selector(newPostButtonTouchUpInside)
        )
        return item
    }()
    
    lazy var helpButton: UIBarButtonItem = { HelpDrawerCoordinator.helpBarButton(for: self) }()
    var helpDrawerType: HelpDrawer { .notifications }
    
    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse(style: .grouped)
        view.dataSource = self.dataSource
        view.delegate = self.delegate
        view.estimatedRowHeight = 64
        view.estimatedSectionHeaderHeight = 50
        view.refreshControl = self.refreshControl
        view.sectionFooterHeight = 0
        view.sectionHeaderHeight = 50
        view.hideTableViewHeader()
        return view
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl.forAutoLayout()
        control.addTarget(self, action: #selector(refreshControlValueChanged(control:)), for: .valueChanged)
        return control
    }()

    private lazy var floatingRefreshButton: FloatingRefreshButton = {
        let button = FloatingRefreshButton()
        button.addTarget(
            self,
            action: #selector(floatingRefreshButtonDidTouchUpInside(button:)),
            for: .touchUpInside
        )
        return button
    }()

    // MARK: Lifecycle

    init() {
        super.init(scrollable: false, title: .notifications)
        navigationItem.rightBarButtonItems = [newPostBarButtonItem, helpButton]
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.view, with: self.tableView)
        self.floatingRefreshButton.layout(in: self.view, below: self.tableView)
        registerNotifications()
        
        if dataSource.reports.isEmpty {
            // Sometimes the reports get loaded before the user opens this view, triggered by `fillMessages` posting
            // a notification
            self.addLoadingAnimation()
            self.load()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Notifications")
        Analytics.shared.trackDidShowScreen(screenName: "notifications")
        AppController.shared.promptForPushNotificationsIfNotDetermined(in: self)
        HelpDrawerCoordinator.showFirstTimeHelp(for: self)
    }

    // MARK: Load and refresh

    @MainActor
    func load(animated: Bool = false) {
        Task {
            let clean = { [weak self] in
                self?.removeLoadingAnimation()
                self?.refreshControl.endRefreshing()
                self?.floatingRefreshButton.hide()
            }
            do {
                let reports = try await Bots.current.reports()
                clean()
                update(with: reports, animated: animated)
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                clean()
                alert(error: error)
            }
        }
    }

    private func update(with reports: [Report], animated: Bool = true) {
        self.dataSource.reports = reports
        lastTimeNewReportsUpdatesWasChecked = Date()
        self.tableView.reloadData()
    }

    func checkForNotificationUpdates(force: Bool = false) {
        if force {
            lastTimeNewReportsUpdatesWasChecked = .distantPast
        }
        // Check that more than a minute passed since the last time we checked for new updates
        let elapsed = Date().timeIntervalSince(lastTimeNewReportsUpdatesWasChecked)
        guard elapsed > 60 else {
            return
        }
        let currentReports = self.dataSource.reports
        let reportAtTop = currentReports.first
        if let report = reportAtTop {
            lastTimeNewReportsUpdatesWasChecked = Date()
            let operation = NumberOfReportsOperation(lastReport: report)
            operation.completionBlock = { [weak self] in
                let numberOfNewReports = operation.numberOfReports
                if numberOfNewReports > 0 {
                    DispatchQueue.main.async { [weak self] in
                        let shouldAnimate = self?.navigationController?.topViewController == self
                        self?.floatingRefreshButton.setTitle(with: numberOfNewReports)
                        self?.floatingRefreshButton.show(animated: shouldAnimate)
                    }
                }
            }
            AppController.shared.addOperation(operation)
        } else {
            // If the feed is empty, we just try to fetch the new updates and show them
            load(animated: false)
        }
    }

    // MARK: Actions

    @objc
    func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        load()
    }

    @objc
    func floatingRefreshButtonDidTouchUpInside(button: FloatingRefreshButton) {
        button.hide()
        self.refreshControl.beginRefreshing()
        self.tableView.setContentOffset(CGPoint(x: 0, y: -self.refreshControl.frame.height), animated: false)
        self.load(animated: true)
    }

    // MARK: Notifications

    override func registerNotifications() {
        super.registerNotifications()
        self.registerDidRefresh()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didCreateReport(notification:)),
            name: .didCreateReport,
            object: nil
        )
    }
    
    override func didRefresh(notification: Notification) {
        checkForNotificationUpdates()
    }

    @objc
    func didCreateReport(notification: Notification) {
        checkForNotificationUpdates(force: true)
    }
    
    @objc
    func newPostButtonTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "compose")
        let controller = NewPostViewController()
        controller.didPublish = { [weak self] _ in
            self?.load()
        }
        let navController = UINavigationController(rootViewController: controller)
        self.present(navController, animated: true, completion: nil)
    }
}

private class NotificationsTableViewDataSource: MessageTableViewDataSource {

    var reports: [Report] = [] {
        didSet {

            // segment keyvalues by date
            var today: [Report] = []
            var yesterday: [Report] = []
            var earlier: [Report] = []
            for report in reports {
                if Calendar.current.isDateInToday(report.createdAt) {
                    today += [report]
                } else if Calendar.current.isDateInYesterday(report.createdAt) {
                    yesterday += [report]
                } else {
                    earlier += [report]
                }
            }

            // label each section
            var sections: [(Localized, [Report])] = []
            if today.count > 0 { sections += [(.today, today)] }
            if yesterday.count > 0 { sections += [(.yesterday, yesterday)] }
            if earlier.count > 0 { sections += [(.recently, earlier)] }
            self.sectionedReports = sections
            
            self.messages = reports.map { $0.message }
        }
    }

    fileprivate func report(at indexPath: IndexPath) -> Report {
        let (_, reports) = self.sectionedReports[indexPath.section]
        return reports[indexPath.row]
    }

    fileprivate var sectionedReports: [(Localized, [Report])] = []

    override func message(at indexPath: IndexPath) -> Message {
        report(at: indexPath).message
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        self.sectionedReports.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let (_, reports) = self.sectionedReports[section]
        return reports.count
    }

    override func cell(
        at indexPath: IndexPath,
        for type: ContentType,
        tableView: UITableView
    ) -> MessageTableViewCell {
        let view = NotificationCellView()
        view.constrainHeight(greaterThanOrEqualTo: 64)
        let cell = MessageTableViewCell(for: type, with: view)
        return cell
    }
}

extension NotificationsViewController: TopScrollable {
    func scrollToTop() {
        self.tableView.scrollToTop()
    }
}

private class NotificationsTableViewDelegate: MessageTableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let source = tableView.dataSource as? NotificationsTableViewDataSource else { return nil }
        let (title, _) = source.sectionedReports[section]
        return HeaderView(title: title.text, showClearNotificationsButton: section == 0)
    }

    override func tableView(_ tableView: UITableView, didSelect message: Message) {

        if message.contentType == .contact {
            Analytics.shared.trackDidSelectItem(kindName: "identity")
            let identity = message.author
            let controller = IdentityViewBuilder.build(identity: identity)
            self.viewController?.navigationController?.pushViewController(controller, animated: true)
        } else if message.contentType == .post {
            Analytics.shared.trackDidSelectItem(kindName: "post")
            let controller = ThreadViewController(with: message)
            self.viewController?.navigationController?.pushViewController(controller, animated: true)
        }
    }

    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        guard let source = tableView.dataSource as? NotificationsTableViewDataSource else {
            return
        }
        let (_, reports) = source.sectionedReports[indexPath.section]
        let report = reports[indexPath.row]
        if report.isUnread {
            Bots.current.markMessageAsRead(report.messageIdentifier)
        }
    }
}

private class HeaderView: UITableViewHeaderFooterView {

    private lazy var button: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = Localized.Notifications.markAllAsRead.text
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            return outgoing
        }
        let view = UIButton(configuration: configuration)
        view.useAutoLayout()
        view.addTarget(
            self,
            action: #selector(clearNotificationsButtonTouchUpInside),
            for: .touchUpInside
        )
        return view
    }()

    let label: UILabel = {
        let view = UILabel.forAutoLayout()
        view.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        return view
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        self.contentView.backgroundColor = .cardBackground
        self.useAutoLayout()
        Layout.addSeparator(toTopOf: self.contentView)
        Layout.fillRight(
            of: self.contentView,
            with: button,
            insets: UIEdgeInsets(top: 1, left: 18, bottom: 1, right: -18)
        )
        Layout.fillLeft(
            of: self.contentView,
            with: self.label,
            insets: UIEdgeInsets(top: 1, left: 18, bottom: 1, right: -18)
        )
        Layout.addSeparator(toBottomOf: self.contentView)
    }

    convenience init(title: String, showClearNotificationsButton: Bool = false) {
        self.init(frame: .zero)
        self.label.text = title
        button.isHidden = !showClearNotificationsButton
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    @objc
    func clearNotificationsButtonTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "clear-notifications")
        let clearUnreadNotificationsOperation = ClearUnreadNotificationsOperation()
        AppController.shared.showProgress()
        clearUnreadNotificationsOperation.completionBlock = {
            DispatchQueue.main.async {
                AppController.shared.hideProgress()
            }
        }
        AppController.shared.addOperation(clearUnreadNotificationsOperation)
    }
}
