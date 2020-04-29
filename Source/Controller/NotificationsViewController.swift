//
//  NotificationsViewController.swift
//  FBTT
//
//  Created by Christoph on 6/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class NotificationsViewController: ContentViewController {

    private let dataSource = NotificationsTableViewDataSource()
    private lazy var delegate = NotificationsTableViewDelegate(on: self)

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
        AppController.shared.promptForPushNotificationsIfNotDetermined(in: self)
        self.deeregisterDidSync()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.registerDidSync()
    }

    // MARK: Load and refresh

    func load() {
        Bots.current.notifications() {
            [weak self] msgs, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.removeLoadingAnimation()
            self?.refreshControl.endRefreshing()
            
            if let error = error {
                self?.alert(error: error)
            } else {
                self?.update(with: msgs, animated: false)
            }
        }
    }

    func refresh() {
        Bots.current.refresh(load: .medium, queue: .main) {
            _, _ in
            self.load()
        }
    }

    private func update(with feed: Feed?, animated: Bool = true) {
        guard let feed = feed else { return }
        self.dataSource.keyValues = feed
        self.tableView.reloadData()
    }

    // MARK: Actions

    @objc func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.refresh()
    }

    // MARK: Notifications

    override func registerNotifications() {
        super.registerNotifications()
        self.registerDidSync()
    }

    override func deregisterNotifications() {
        super.deregisterNotifications()
        self.deeregisterDidSync()
    }

    /// Refreshes the view,  but only if this is the top controller, not when there are any child
    /// controllers.  The notification will also only be received when the view is not visible,
    /// check out `viewDidAppear()` and `viewDidDisappear()`.  This is because
    /// we don't want the view to be updated while someone is looking/scrolling it.
    override func didSync(notification: NSNotification) {
        DispatchQueue.main.async {
            guard self.navigationController?.topViewController == self else {
                return
            }
            // TODO: Just say that there are new updates
            // self.refresh()
        }
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

    override var keyValues: KeyValues {
        didSet {

            // segment keyvalues by date
            var today: KeyValues = []
            var yesterday: KeyValues = []
            var earlier: KeyValues = []
            for keyValue in keyValues {
                if      Calendar.current.isDateInToday(keyValue.userDate)     { today += [keyValue] }
                else if Calendar.current.isDateInYesterday(keyValue.userDate) { yesterday += [keyValue] }
                else                                                                { earlier += [keyValue] }
            }

            // label each section
            var sections: [(Text, KeyValues)] = []
            if today.count > 0      { sections += [(.today, today)] }
            if yesterday.count > 0  { sections += [(.yesterday, yesterday)] }
            if earlier.count > 0    { sections += [(.recently, earlier)] }
            self.sectionedKeyValues = sections
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
            let controller = AboutViewController(with: keyValue.value.author)
            self.viewController?.navigationController?.pushViewController(controller, animated: true)
        }

        else if keyValue.contentType == .post {
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
        self.contentView.backgroundColor = UIColor.background.default
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
