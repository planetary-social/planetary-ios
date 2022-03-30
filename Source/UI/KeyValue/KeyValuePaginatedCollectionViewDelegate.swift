//
//  KeyValuePaginatedCollectionViewDelegate.swift
//  Planetary
//
//  Created by Martin Dutra on 6/19/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class KeyValuePaginatedCollectionViewDelegate: NSObject {
    
    /// View controller that will be used for navigating
    /// when the keyValue is selected.
    weak var viewController: UIViewController?

    init(on viewController: UIViewController) {
        self.viewController = viewController
    }
}

extension KeyValuePaginatedCollectionViewDelegate: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let dataSource = collectionView.dataSource as? KeyValuePaginatedCollectionViewDataSource else {
            return
        }
        guard let keyValue = dataSource.data.keyValueBy(index: indexPath.row) else {
            return
        }
        let controller = ThreadViewController(with: keyValue)
        self.viewController?.navigationController?.pushViewController(controller, animated: true)
    }
}
