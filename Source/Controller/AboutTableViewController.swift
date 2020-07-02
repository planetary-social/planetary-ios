//
//  AboutTableViewController.swift
//  Planetary
//
//  Created by Martin Dutra on 7/2/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

class AboutTableViewController: UITableViewController {

    var abouts: [About] = []

    // MARK: - UITableViewDataSource functions

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.abouts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: AboutTableViewCell.className) as? AboutTableViewCell) ?? AboutTableViewCell()
        let about = self.abouts[indexPath.row]
        cell.aboutView.update(with: about.identity, about: about)
        return cell
    }

    // MARK: - UITableViewDelegate functions

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Analytics.shared.trackDidSelectItem(kindName: "identity")

        let about = self.abouts[indexPath.row]
        let targetController = self.navigationController

        let controller = AboutViewController(with: about)
        targetController?.pushViewController(controller, animated: true)
    }

}
