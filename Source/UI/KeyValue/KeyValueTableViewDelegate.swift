//
//  PostTableViewDelegate.swift
//  FBTT
//
//  Created by Christoph on 4/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class KeyValueTableViewDelegate: NSObject, UITableViewDelegate {

    /// View controller that will be used for navigating
    /// when the keyValue is selected.
    weak var viewController: UIViewController?

    init(on viewController: UIViewController) {
        self.viewController = viewController
    }

    // MARK: Handle tap event elsewhere in the `cell.contentView`

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let keyValue = tableView.keyValue(for: indexPath) else { return }
        self.tableView(tableView, didSelect: keyValue)
    }

    func tableView(_ tableView: UITableView, didSelect keyValue: KeyValue) {
        self.pushViewController(for: keyValue)
    }

    // MARK: Configure KeyValueView.tapGesture

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? KeyValueTableViewCell else { return }
        guard let keyValue = tableView.keyValue(for: indexPath) else { return }
        cell.keyValueView.tapGesture.tap = {
            [weak self] in
            self?.tableView(tableView, didSelect: keyValue)
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? KeyValueTableViewCell else { return }
        cell.keyValueView.tapGesture.tap = nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        10
    }

    // MARK: Navigating with controller

    private func pushViewController(for keyValue: KeyValue) {
        guard let controller = self.viewController(for: keyValue) else { return }
        self.viewController?.navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: Controller for ContentType

    private func viewController(for keyValue: KeyValue) -> UIViewController? {
        switch keyValue.contentType {
            default: return nil
        }
    }
}
