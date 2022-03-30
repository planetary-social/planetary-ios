//
//  UICollectionView+Verse.swift
//  Planetary
//
//  Created by Martin Dutra on 6/15/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

extension UICollectionView {
    
    func scrollToTop(animated: Bool = true) {
        // let point = CGPoint(x: 0, y: -self.contentInset.top)
        let point = CGPoint(x: -self.contentInset.left, y: -self.contentInset.top)
        DispatchQueue.main.async {
            self.setContentOffset(point, animated: animated)
        }
    }
}
