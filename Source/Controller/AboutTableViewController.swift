//
//  AboutTableViewController.swift
//  Planetary
//
//  Created by Martin Dutra on 7/2/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit
import Analytics

class AboutTableViewController: UITableViewController, UISearchResultsUpdating {

    var allAbouts = [About]() {
        didSet {
            self.applyFilter()
        }
    }

    // filtered collection for display
    var filteredAbouts = [About]() {
        didSet {
            self.tableView.reloadData()
        }
    }

    // text on which to filter results
    private var filter = "" {
        didSet {
            self.applyFilter()
        }
    }

    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchResultsUpdater = self
        controller.searchBar.delegate = self
        controller.searchBar.isTranslucent = false
        controller.obscuresBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        return controller
    }()

    // for a bug fix — see note in UISearchBarDelegate extension below
    private var searchEditBeginDate = Date()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .appBackground
        
        self.removeBackItemText()

        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshControlValueChanged(control:)), for: .valueChanged)
        self.refreshControl = refreshControl

        self.tableView.tableHeaderView = UIView(frame: CGRect(origin: .zero,
                                                              size: CGSize(width: tableView.frame.size.width,
                                                                           height: 10)))
        
        self.tableView.separatorInset = .zero
        self.tableView.separatorColor = UIColor.separator.middle
    }

    func applyFilter() {
        if self.filter.isEmpty {
            self.filteredAbouts = self.allAbouts
        } else {
            let filter = self.filter.lowercased()
            self.filteredAbouts = self.allAbouts.filter { about in
                let containsName = about.name?.lowercased().contains(filter) ?? false
                let containsIdentity = about.identity.lowercased().contains(filter)
                return containsName || containsIdentity
            }
        }
    }
    
    func load(completion: @escaping () -> Void) {
        completion()
    }

    @objc func refreshControlValueChanged(control: UIRefreshControl) {
        control.beginRefreshing()
        self.load {
            control.endRefreshing()
        }
    }

    // MARK: - UITableViewDataSource functions

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.filteredAbouts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: AboutTableViewCell.className) as? AboutTableViewCell) ?? AboutTableViewCell()
        let about = self.filteredAbouts[indexPath.row]
        cell.aboutView.update(with: about.identity, about: about)
        return cell
    }

    // MARK: - UITableViewDelegate functions

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Analytics.shared.trackDidSelectItem(kindName: "identity")

        let about = self.filteredAbouts[indexPath.row]
        let targetController = self.navigationController

        let controller = AboutViewController(with: about)
        targetController?.pushViewController(controller, animated: true)
    }

    // MARK: - UISearchResultsUpdating functions

    func updateSearchResults(for searchController: UISearchController) {
        Analytics.shared.trackDidTapSearchbar(searchBarName: "about_table")
        self.filter = searchController.searchBar.text ?? ""
    }

}

// MARK: - UISearchBarDelegate functions

extension AboutTableViewController: UISearchBarDelegate {

    // These two functions are implemented to avoid a bug where the initial
    // tap of the search bar begins editing, but first responder is immediately resigned
    // I can't figure out why this is happening, but this is a potential solution to avoid the bug.
    // I set a symbolic breakpoint and can't find why resignFirstResponder is being called there.
    //
    // first, when the edit begins, we store the date in self.searchEditBeginDate
    // then, in searchBarShouldEndEditing, we check whether this date was extremely recent
    // if it was too recent to be performed intentionally, we don't allow the field to end editing.
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        self.searchEditBeginDate = Date()
        return true
    }

    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        let timeSinceStart = Date().timeIntervalSince(self.searchEditBeginDate)
        return timeSinceStart > 0.4
    }
    
}
