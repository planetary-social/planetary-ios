//
//  DirectoryOnboardingStep.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger

class DirectoryOnboardingStep: OnboardingStep, UITableViewDataSource, UITableViewDelegate {

    private lazy var tableView: UITableView = {
        let view = UITableView.forVerse()
        view.dataSource = self
        view.delegate = self
        view.separatorColor = UIColor.separator.middle
        return view
    }()

    private var people: [Person] = []
    private var selected: Set<Person> = []

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
    }

    @objc func didPressNext(sender button: UIButton) {
        self.performPrimaryAction(sender: button)
    }

    override func performPrimaryAction(sender button: UIButton) {

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
        
        /*
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
            Onboarding.invitePubsToFollow(context.identity) {
                [weak self] success, error in
                Log.optional(error)
                self?.view.lookReady()
                guard success else { return }
                self?.next()
            }
        }
        */
    }

    // MARK: table stuff

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.people.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AboutTableViewCell.className) as? AboutTableViewCell ?? AboutTableViewCell()
        let person = self.people[indexPath.row]
        cell.aboutView.update(with: person, useRelationship: false)
        cell.aboutView.followButton.isSelected = self.selected.contains(person)
        cell.aboutView.followButton.action = { _ in
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
