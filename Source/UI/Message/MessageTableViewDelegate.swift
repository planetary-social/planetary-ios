//
//  MessageTableViewDelegate.swift
//  FBTT
//
//  Created by Christoph on 4/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class MessageTableViewDelegate: NSObject, UITableViewDelegate {

    /// View controller that will be used for navigating
    /// when the message is selected.
    weak var viewController: UIViewController?

    init(on viewController: UIViewController) {
        self.viewController = viewController
    }

    // MARK: Handle tap event elsewhere in the `cell.contentView`

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let message = tableView.message(for: indexPath) else { return }
        self.tableView(tableView, didSelect: message)
    }

    func tableView(_ tableView: UITableView, didSelect message: Message) {
        self.pushViewController(for: message)
    }

    // MARK: Configure MessageView.tapGesture

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? MessageTableViewCell else { return }
        guard let message = tableView.message(for: indexPath) else { return }
        cell.messageView.tapGesture.tap = {
            [weak self] in
            self?.tableView(tableView, didSelect: message)
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? MessageTableViewCell else { return }
        cell.messageView.tapGesture.tap = nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        10
    }

    // MARK: Navigating with controller

    private func pushViewController(for message: Message) {
        guard let controller = self.viewController(for: message) else { return }
        self.viewController?.navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: Controller for ContentType

    private func viewController(for message: Message) -> UIViewController? {
        switch message.contentType {
            default: return nil
        }
    }
}
