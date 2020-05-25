//
//  DirectoryOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class DirectoryOnboardingStep: OnboardingStep, UITableViewDataSource, UITableViewDelegate {

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self
        view.delegate = self
        view.separatorColor = UIColor.separator.middle
        return view
    }()
    
    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchResultsUpdater = self
        controller.searchBar.delegate = self
        controller.searchBar.isTranslucent = false
        controller.obscuresBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        return controller
    }()

    // unfiltered collection
    private var allPeople = [Person]() {
        didSet {
            self.applyFilter()
        }
    }
    
    // filtered collection for display
    private var people = [Person]() {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    private var selected: Set<Person> = []
    
    // text on which to filter results
    private var filter = "" {
        didSet {
            self.applyFilter()
        }
    }
    
    private func applyFilter() {
        if self.filter.isEmpty {
            self.people = self.allPeople
        } else {
            let filter = self.filter.lowercased()
            self.people = self.allPeople.filter {
                person in
                return person.name.lowercased().contains(filter) || person.identity.lowercased().contains(filter)
            }
        }
    }
    
    // for a bug fix — see note in Search extension below
    private var searchEditBeginDate = Date()

    init() {
        super.init(.directory)
        self.showsNavigationBar = true
    }

    override func customizeView() {
        self.view.titleLabel.isHidden = true

        let topSeparator = Layout.addSeparator(toTopOf: self.view)

        let bottomSeparator = Layout.separatorView()
        Layout.fillNorth(of: self.view.buttonStack, with: bottomSeparator)

        Layout.fillSouth(of: topSeparator, with: self.tableView)
        self.tableView.pinBottom(toTopOf: bottomSeparator)

        self.view.primaryButton.isHidden = true
    }

    override func customizeController(controller: ContentViewController) {
        let nextButton = UIBarButtonItem(title: Text.next.text, style: .plain, target: self, action: #selector(didPressNext))
        controller.navigationItem.rightBarButtonItem = nextButton
        controller.navigationItem.hidesBackButton = true
        controller.navigationItem.searchController = self.searchController

        controller.definesPresentationContext = true
        controller.extendedLayoutIncludesOpaqueBars = false
    }


    override func didStart() {
        self.view.lookBusy()
        DirectoryAPI.shared.directory(includeMe: true) {
            [weak self] people, error in
            self?.allPeople = people
            self?.tableView.reloadData()
            self?.view.lookReady()
        }
    }

    @objc func didPressNext() {
        self.primary()
    }

    override func primary() {

        var identities = self.selected.map { $0.identity }
        self.data.following = identities

        // SIMULATE ONBOARDING
        if self.data.simulated { self.next(); return }

        guard let context = self.data.context else {
            Log.unexpected(.missingValue, "Expecting self.data.context, skipping step")
            self.next()
            return
        }

        self.view.lookBusy(disable: self.view.primaryButton)

        // follow identities
        // TODO: make sure this uses the identities from the integration test network https://app.asana.com/0/0/1134329918920786/f
        identities += Identities.for(context.network)
        Onboarding.follow(identities, context: context) {
            [weak self] success, contacts, errors in
            guard success else {
                self?.view.lookReady()
                return
            }

            // invite pubs
            Onboarding.invitePubsToFollow(context.identity) { [weak self] success, error in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                DispatchQueue.main.async { [weak self] in
                    self?.view.lookReady()
                    if success {
                        self?.next()
                    } else if let error = error {
                        AppController.shared.alert(error: error)
                    } else {
                        AppController.shared.alert(error: AppError.unexpected)
                    }
                }
            }
        }
    }

    // MARK: table stuff

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.people.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AboutTableViewCell.className) as? AboutTableViewCell ?? AboutTableViewCell()
        let person = self.people[indexPath.row]
        cell.aboutView.update(with: person, useRelationship: false)
        cell.aboutView.followButton.isSelected = self.selected.contains(person)
        cell.aboutView.followButton.action = {
            self.tableView(tableView, didSelectRowAt: indexPath)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let person = self.people[indexPath.row]
        if self.selected.contains(person) {
            self.selected.remove(person)
        } else {
            self.selected.insert(person)
        }
        tableView.reloadRows(at: [indexPath], with: .none)
    }
}

extension DirectoryOnboardingStep: UISearchResultsUpdating, UISearchBarDelegate {

    func updateSearchResults(for searchController: UISearchController) {
        self.filter = searchController.searchBar.text ?? ""
    }

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
