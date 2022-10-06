//
//  MessagePaginatedCollectionViewDataSource.swift
//  Planetary
//
//  Created by Martin Dutra on 6/15/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

class MessagePaginatedCollectionViewDataSource: NSObject {
    
    var data: PaginatedMessageDataProxy = StaticDataProxy()
    
    func update(source: PaginatedMessageDataProxy) {
        self.data = source
    }
}

extension MessagePaginatedCollectionViewDataSource: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.data.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Post", for: indexPath) as! PostCollectionViewCell
        let latePrefetch = { (_: Int, message: Message) -> Void in
          DispatchQueue.main.async {
            cell.update(message: message)
            collectionView.collectionViewLayout.invalidateLayout()
          }
        }
        if let message = self.data.messageBy(index: indexPath.row, late: latePrefetch) {
            cell.update(message: message)
            collectionView.collectionViewLayout.invalidateLayout()
        }
        return cell
    }
}

extension MessagePaginatedCollectionViewDataSource: UICollectionViewDataSourcePrefetching {
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        if let biggest = indexPaths.max()?.row {
            // prefetch everything up to the last row
            self.data.prefetchUpTo(index: biggest)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // ignore cancels since we cant stop running querys anyhow
    }
}
