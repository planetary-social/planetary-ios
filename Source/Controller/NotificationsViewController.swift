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

class NotificationsViewController: ContentViewController {

    private static var refreshBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    private let dataSource = NotificationsTableViewDataSource()
    private lazy var delegate = NotificationsTableViewDelegate(on: self)
    
    
    private lazy var newPostBarButtonItem: UIBarButtonItem = {
        let image = UIImage(named: "nav-icon-write")
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(newPostButtonTouchUpInside))
        return item
    }()
    
    
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

    // MARK: Lifecycle

    init() {
        super.init(scrollable: false, title: .notifications)
        self.navigationItem.rightBarButtonItems = [self.newPostBarButtonItem]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.view, with: self.tableView)
        self.addLoadingAnimation()
        self.load()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        CrashReporting.shared.record("Did Show Notifications")
        Analytics.shared.trackDidShowScreen(screenName: "notifications")
        AppController.shared.promptForPushNotificationsIfNotDetermined(in: self)
        self.deeregisterDidRefresh()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.registerDidRefresh()
    }

    // MARK: Load and refresh

    func load(animated: Bool = false) {
        Bots.current.reports() { [weak self] reports, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.removeLoadingAnimation()
            self?.refreshControl.endRefreshing()
            
            if let error = error {
                self?.alert(error: error)
            } else {
                self?.update(with: reports, animated: animated)
            }
        }
    }

    func refreshAndLoad(animated: Bool = false) {
        if NotificationsViewController.refreshBackgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(NotificationsViewController.refreshBackgroundTaskIdentifier)
        }
        
        Log.info("Pull down to refresh triggering a short refresh")
        let refreshOperation = RefreshOperation(refreshLoad: .short)
        
        let taskName = "NotificationsPullDownToRefresh"
        let taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) {
            // Expiry handler, iOS will call this shortly before ending the task
            refreshOperation.cancel()
            UIApplication.shared.endBackgroundTask(NotificationsViewController.refreshBackgroundTaskIdentifier)
            NotificationsViewController.refreshBackgroundTaskIdentifier = .invalid
        }
        NotificationsViewController.refreshBackgroundTaskIdentifier = taskIdentifier
        
        refreshOperation.completionBlock = { [weak self] in
            Log.optional(refreshOperation.error)
            CrashReporting.shared.reportIfNeeded(error: refreshOperation.error)
            
            if taskIdentifier != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                NotificationsViewController.refreshBackgroundTaskIdentifier = .invalid
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.load(animated: animated)
            }
        }
        AppController.shared.operationQueue.addOperation(refreshOperation)
    }

    private func update(with reports: [Report], animated: Bool = true) {
        self.dataSource.reports = reports
        self.tableView.reloadData()
    }

    // MARK: Actions

    @objc func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.refreshAndLoad()
    }

    // MARK: Notifications

    override func registerNotifications() {
        super.registerNotifications()
        self.registerDidRefresh()
    }

    override func deregisterNotifications() {
        super.deregisterNotifications()
        self.deeregisterDidRefresh()
    }

    /// Refreshes the view,  but only if this is the top controller, not when there are any child
    /// controllers.  The notification will also only be received when the view is not visible,
    /// check out `viewDidAppear()` and `viewDidDisappear()`.  This is because
    /// we don't want the view to be updated while someone is looking/scrolling it.
    override func didRefresh(notification: NSNotification) {
        DispatchQueue.main.async {
            guard self.navigationController?.topViewController == self else {
                return
            }
            // TODO: Maybe we want to update the table here
            // Or show a REFRESH button
            // self.load()
        }
    }
    
    
    @objc func newPostButtonTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "compose")
        let controller = NewPostViewController()
        controller.didPublish = {
            [weak self] post in
            self?.load()
        }
        let navController = UINavigationController(rootViewController: controller)
        self.present(navController, animated: true, completion: nil)
    }


    // TODO this won't work because until the data source is updated
    // TODO notifications() will keep returning the same list and the
    // old.key != new.key check will always be true, but this is good
    // research on how to background updates and show changes in the UI
//    func refresh(completion: ((Bool) -> Void)? = nil) {
//        Bots.current.notifications() {
//            [weak self] feed, _ in
            // TODO move to KeyValueDataSource.isOlderThan(feed)
            // TODO assume if different than new?
//            guard let new = feed.first else { return }
//            guard let old = self.dataSource.keyValues.first else { return }
//            guard old.key != new.key else { return }
//            AppController.shared.mainViewController?.updateNotificationsTabIcon(hasNotifications: true)
//            let hasNewContent = (feed.first?.key != self?.dataSource.keyValues.first?.key) ?? false
//            if hasNewContent { self?.update(with: feed) }
//            completion?(hasNewContent)
//        }
//    }
}

fileprivate class NotificationsTableViewDataSource: KeyValueTableViewDataSource {

    var reports: [Report] = [] {
        didSet {

            // segment keyvalues by date
            var today: KeyValues = []
            var yesterday: KeyValues = []
            var earlier: KeyValues = []
            for report in reports {
                if      Calendar.current.isDateInToday(report.createdAt)     { today += [report.keyValue] }
                else if Calendar.current.isDateInYesterday(report.createdAt) { yesterday += [report.keyValue] }
                else                                                                { earlier += [report.keyValue] }
            }

            // label each section
            var sections: [(Text, KeyValues)] = []
            if today.count > 0      { sections += [(.today, today)] }
            if yesterday.count > 0  { sections += [(.yesterday, yesterday)] }
            if earlier.count > 0    { sections += [(.recently, earlier)] }
            self.sectionedKeyValues = sections
            
            self.keyValues = reports.map{$0.keyValue}
        }
    }

    fileprivate var sectionedKeyValues: [(Text, KeyValues)] = []

    override func keyValue(at indexPath: IndexPath) -> KeyValue {
        let (_, keyValues) = self.sectionedKeyValues[indexPath.section]
        return keyValues[indexPath.row]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sectionedKeyValues.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let (_, keyValues) = self.sectionedKeyValues[section]
        return keyValues.count
    }

    override func cell(at indexPath: IndexPath, for type: ContentType, tableView: UITableView) -> KeyValueTableViewCell {
        let view = NotificationCellView()
        view.constrainHeight(greaterThanOrEqualTo: 64)
        let cell = KeyValueTableViewCell(for: type, with: view)
        return cell
    }
    
}

extension NotificationsViewController: TopScrollable {
    func scrollToTop() {
        self.tableView.scrollToTop()
    }
}

fileprivate class NotificationsTableViewDelegate: KeyValueTableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let source = tableView.dataSource as? NotificationsTableViewDataSource else { return nil }
        let (title, _) = source.sectionedKeyValues[section]
        return HeaderView(title: title.text)
    }

    override func tableView(_ tableView: UITableView, didSelect keyValue: KeyValue) {

        if keyValue.contentType == .contact {
            Analytics.shared.trackDidSelectItem(kindName: "identity")
            let controller = AboutViewController(with: keyValue.value.author)
            self.viewController?.navigationController?.pushViewController(controller, animated: true)
        }

        else if keyValue.contentType == .post {
            Analytics.shared.trackDidSelectItem(kindName: "post")
            let controller = ThreadViewController(with: keyValue)
            self.viewController?.navigationController?.pushViewController(controller, animated: true)
        }
    }
}

fileprivate class HeaderView: UITableViewHeaderFooterView {

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
        Layout.fill(view: self.contentView,
                    with: self.label,
                    insets: UIEdgeInsets(top: 1, left: 18, bottom: 1, right: -18))
        Layout.addSeparator(toBottomOf: self.contentView)
    }

    convenience init(title: String) {
        self.init(frame: .zero)
        self.label.text = title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
