//
//  KnownPubsTableViewDataSource.swift
//  Planetary
//
//  Created by Martin Dutra on 5/14/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

protocol KnownPubsTableViewDataSourceDelegate: class {
    func reload()
}


class KnownPubsTableViewDataSource: NSObject {

    var knownPubs: KnownPubs {
        didSet {
            self.load()
        }
    }

    private var abouts: [Identity: About] = [:]

    weak var delegate: KnownPubsTableViewDataSourceDelegate?

    init(knownPubs: KnownPubs) {
        self.knownPubs = knownPubs
        super.init()
        self.load()
    }

    private func load() {
        let identities = Array(self.knownPubs.prefix(10)).map{ $0.ForFeed }
        self.loadAbouts(for: identities) {
            [weak self] in
            self?.delegate?.reload()
        }
    }

    private func loadAbouts(for identities: [Identity], completion: (() -> Void)? = nil) {
        Bots.current.abouts(identities: identities) {
            [weak self] abouts, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            abouts.forEach { [weak self] in
                self?.abouts[$0.identity] = $0
            }
            completion?()
        }
    }
}

extension KnownPubsTableViewDataSource: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        if self.knownPubs.isEmpty {
            return 1
        }
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return self.knownPubs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "defaultCell") ?? UITableViewCell(style: .default, reuseIdentifier: "defaultCell")
            cell.textLabel?.text = Text.redeemInvitation.text
            cell.accessoryType = .disclosureIndicator
            return cell
        } else {
            let knownPub = knownPubs[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "subtitleCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "subtitleCell")
            if let index = self.abouts.index(forKey: knownPub.ForFeed) {
                cell.textLabel?.text = self.abouts[index].value.name ?? knownPub.ForFeed
            } else {
                cell.textLabel?.text = knownPub.ForFeed
            }
            cell.detailTextLabel?.text = "\(Text.ManagePubs.lastWorked.text): \(knownPub.WorkedLast)"
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return Text.ManagePubs.addingPubs.text
        }
        return Text.ManagePubs.yourPubs.text
    }
    
}

// MARK:- Data source to prefetch About while scrolling

extension KnownPubsTableViewDataSource: UITableViewDataSourcePrefetching {

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        let indexes = indexPaths.map { $0.row }
        let identities = Set(self.knownPubs.elements(at: indexes).map{$0.ForFeed})
        let unfetchedIdentities = identities.subtracting(Set(self.abouts.keys))
        self.loadAbouts(for: Array(unfetchedIdentities))
    }
}
