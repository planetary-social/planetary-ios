//
//  AboutTableViewDataSource.swift
//  Planetary
//
//  Created by Zef Houssney on 10/14/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger
import Analytics
import CrashReporting
import SwiftUI

protocol AboutTableViewDelegate: AnyObject {
    func reload()
    var navigationController: UINavigationController? { get }
}

extension AboutTableViewDelegate where Self: ContentViewController {
    var navigationController: UINavigationController? {
        self.navigationController
    }
}

class AboutTableViewDataSource: NSObject {

    var identities: [Identity] {
        didSet {
            self.load()
        }
    }

    private var abouts: [Identity: About] = [:]

    var delegate: AboutTableViewDelegate?

    init(identities: [Identity]) {
        self.identities = identities
        super.init()
        self.load()
    }

    private func load() {
        let identities = Array(self.identities.prefix(10))
        self.loadAbouts(for: identities) { [weak self] in
            self?.delegate?.reload()
        }
    }

    private func loadAbouts(for identities: [Identity], completion: (() -> Void)? = nil) {
        Bots.current.abouts(identities: identities) { [weak self] abouts, error in
            CrashReporting.shared.reportIfNeeded(error: error)
            if Log.optional(error) { return }
            for about in abouts { self?.abouts[about.identity] = about }
            completion?()
        }
    }
}

extension AboutTableViewDataSource: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.identities.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (
            tableView.dequeueReusableCell(withIdentifier: AboutTableViewCell.className) as? AboutTableViewCell
        ) ?? AboutTableViewCell()
        let identity = self.identities[indexPath.row]
        cell.aboutView.update(with: identity, about: self.abouts[identity])
        return cell
    }
}

// MARK: - Data source to prefetch About while scrolling

extension AboutTableViewDataSource: UITableViewDataSourcePrefetching {

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        let indexes = indexPaths.map { $0.row }
        let identities = Set(self.identities.elements(at: indexes))
        let unfetchedIdentities = identities.subtracting(Set(self.abouts.keys))
        print("prefetch", unfetchedIdentities)
        self.loadAbouts(for: Array(unfetchedIdentities))
    }
}

// MARK: - Delegate to handle tapping a cell

extension AboutTableViewDataSource: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Analytics.shared.trackDidSelectItem(kindName: "identity")
        let identity = self.identities[indexPath.row]
        let controller = UIHostingController(
            rootView: IdentityView(identity: identity).environmentObject(BotRepository.shared)
        )
        let targetController = self.delegate?.navigationController
        targetController?.pushViewController(controller, animated: true)
    }
}
