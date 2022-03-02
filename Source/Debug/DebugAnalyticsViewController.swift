//
//  DebugAnalyticsViewController.swift
//  Planetary
//
//  Created by Christoph on 1/14/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics

class DebugAnalyticsViewController: UIViewController {

    private lazy var searchController: UISearchController = {

        let controller = UISearchController(searchResultsController: self.lexiconController)
        controller.hidesNavigationBarDuringPresentation = false
        controller.isActive = true
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchResultsUpdater = self.lexiconController

        let bar = controller.searchBar
        bar.isTranslucent = false
        bar.placeholder = "Filter event names"
        if #available(iOS 13.0, *) {
            bar.searchTextField.autocapitalizationType = .none
        }
        bar.showsCancelButton = false

        return controller
    }()

    private lazy var lexiconController = LexiconTableViewController()

    convenience init() {
        self.init(nibName: nil, bundle: nil)
        self.navigationItem.hidesSearchBarWhenScrolling = false
        self.navigationItem.searchController = self.searchController
        self.navigationItem.title = "Events"
    }

    override func viewDidLoad() {

        super.viewDidLoad()
        self.view.backgroundColor = .appBackground
        Layout.fill(view: self.view, with: self.lexiconController.view)
        self.lexiconController.view.isHidden = false

        let button = UIBarButtonItem(title: "All",
                                     style: .plain,
                                     target: self,
                                     action: #selector(filterButtonTouchUpInside(button:)))
        self.navigationItem.rightBarButtonItem = button
    }

    @objc
    private func filterButtonTouchUpInside(button: UIBarButtonItem) {

        if button.title == "All" {
            button.title = "Tracked"
            self.lexiconController.filterByTracked = true
        }

        else if button.title == "Tracked" {
            button.title = "All"
            self.lexiconController.filterByTracked = false
        }
    }
}

fileprivate class LexiconTableViewController: UITableViewController, UISearchResultsUpdating {

    private var searchText = ""
    private let names = Analytics.shared.lexicon()
    private var filteredNames: [String] = []

    var filterByTracked: Bool = false {
        didSet {
            self.filter()
        }
    }

    convenience init() {
        self.init(style: .plain)
        self.tableView.contentInsetAdjustmentBehavior = .scrollableAxes
        self.filteredNames = self.names
        self.tableView.reloadData()
    }

    private func namesToFilter() -> [String] {
        if self.filterByTracked {
            let names = Array(Set(self.names).intersection(Analytics.shared.trackedEvents()))
            return names.sorted()
        } else {
            return self.names
        }
    }

    // MARK: Filtering

    private func filter() {

        if self.searchText.isEmpty {
            self.filteredNames = self.namesToFilter()
        }

        else {
            let names = self.namesToFilter().filter {
                return $0.contains(self.searchText.lowercased())
            }
            self.filteredNames = names
        }

        self.tableView.reloadData()
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.filteredNames.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.text = self.filteredNames[indexPath.row]
        let tracked = self.nameHasBeenTracked(for: indexPath)
        cell.textLabel?.textColor = tracked ? UIColor.tint.default : UIColor.text.default
        cell.textLabel?.font = tracked ? UIFont.boldSystemFont(ofSize: 16) : UIFont.systemFont(ofSize: 16)
        return cell
    }

    private func nameHasBeenTracked(for indexPath: IndexPath) -> Bool {
        let name = self.filteredNames[indexPath.row]
        return Analytics.shared.trackedEvents().contains(name)
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard self.filteredNames.count > indexPath.row else { return }
        let string = self.filteredNames[indexPath.row]
        UIPasteboard.general.string = string
    }

    // MARK: UISearchBarDelegate

    func updateSearchResults(for searchController: UISearchController) {
        searchController.searchResultsController?.view.isHidden = false
        self.searchText = searchController.searchBar.text ?? ""
        self.filter()
    }
}
