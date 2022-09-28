//
//  MessagePaginatedTableViewDelegate.swift
//  Planetary
//
//  Created by Martin Dutra on 5/5/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class MessagePaginatedTableViewDelegate: NSObject, UITableViewDelegate {
    
    /// View controller that will be used for navigating
    /// when the message is selected.
    weak var viewController: UIViewController?

    init(on viewController: UIViewController) {
        self.viewController = viewController
    }
    
    // MARK: Handle tap event elsewhere in the `cell.contentView`

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let dataSource = tableView.dataSource as? MessagePaginatedTableViewDataSource else {
            return
        }
        guard let message = dataSource.data.messageBy(index: indexPath.row) else {
            return
        }
        self.tableView(tableView, didSelect: message)
    }

    func tableView(_ tableView: UITableView, didSelect message: Message) {
        self.pushViewController(for: message)
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        10
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let dataSource = tableView.dataSource as? MessagePaginatedTableViewDataSource else {
            return
        }
        guard let message = dataSource.data.messageBy(index: indexPath.row) else {
            return
        }
        Bots.current.markMessageAsRead(message.key)
    }
    
    // MARK: Navigating with controller

    private func pushViewController(for message: Message) {
        guard let controller = self.viewController(for: message) else { return }
        self.viewController?.navigationController?.pushViewController(controller, animated: true)
    }
    
    // MARK: Controller for ContentType

    // Override in subclass
    func viewController(for message: Message) -> UIViewController? {
        switch message.contentType {
        default:
            return nil
        }
    }
}
