//
//  KeyValuePaginatedTableViewDelegate.swift
//  Planetary
//
//  Created by Martin Dutra on 5/5/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class KeyValuePaginatedTableViewDelegate: NSObject, UITableViewDelegate {
    
    /// View controller that will be used for navigating
    /// when the keyValue is selected.
    weak var viewController: UIViewController?

    init(on viewController: UIViewController) {
        self.viewController = viewController
    }
    
    // MARK: Handle tap event elsewhere in the `cell.contentView`

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let dataSource = tableView.dataSource as? KeyValuePaginatedTableViewDataSource else {
            return
        }
        guard let keyValue = dataSource.data.keyValueBy(index: indexPath.row) else {
            return
        }
        self.tableView(tableView, didSelect: keyValue)
    }

    func tableView(_ tableView: UITableView, didSelect keyValue: KeyValue) {
        self.pushViewController(for: keyValue)
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        10
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let dataSource = tableView.dataSource as? KeyValuePaginatedTableViewDataSource else {
            return
        }
        guard let keyValue = dataSource.data.keyValueBy(index: indexPath.row) else {
            return
        }
        Bots.current.markMessageAsRead(keyValue.key)
    }
    
    // MARK: Navigating with controller

    private func pushViewController(for keyValue: KeyValue) {
        guard let controller = self.viewController(for: keyValue) else { return }
        self.viewController?.navigationController?.pushViewController(controller, animated: true)
    }
    
    // MARK: Controller for ContentType

    // Override in subclass
    func viewController(for keyValue: KeyValue) -> UIViewController? {
        switch keyValue.contentType {
        default:
            return nil
        }
    }
}
