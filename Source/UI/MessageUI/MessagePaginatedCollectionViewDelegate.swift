//
//  MessagePaginatedCollectionViewDelegate.swift
//  Planetary
//
//  Created by Martin Dutra on 6/19/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class MessagePaginatedCollectionViewDelegate: NSObject {
    
    /// View controller that will be used for navigating
    /// when the message is selected.
    weak var viewController: UIViewController?

    init(on viewController: UIViewController) {
        self.viewController = viewController
    }
}

extension MessagePaginatedCollectionViewDelegate: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let dataSource = collectionView.dataSource as? MessagePaginatedCollectionViewDataSource else {
            return
        }
        guard let message = dataSource.data.messageBy(index: indexPath.row) else {
            return
        }
        let controller = MessageViewBuilder.build(identifier: message.id)
        self.viewController?.navigationController?.pushViewController(controller, animated: true)
    }
}
