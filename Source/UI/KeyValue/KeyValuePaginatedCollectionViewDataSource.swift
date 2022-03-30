//
//  KeyValuePaginatedCollectionViewDataSource.swift
//  Planetary
//
//  Created by Martin Dutra on 6/15/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

class KeyValuePaginatedCollectionViewDataSource: NSObject {
    
    var data: PaginatedKeyValueDataProxy = StaticDataProxy()
    
    func update(source: PaginatedKeyValueDataProxy) {
        self.data = source
    }
}

extension KeyValuePaginatedCollectionViewDataSource: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.data.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Post", for: indexPath) as! PostCollectionViewCell
        let latePrefetch = { (_: Int, keyValue: KeyValue) -> Void in
          DispatchQueue.main.async {
            cell.update(keyValue: keyValue)
            collectionView.collectionViewLayout.invalidateLayout()
          }
        }
        if let keyValue = self.data.keyValueBy(index: indexPath.row, late: latePrefetch) {
            cell.update(keyValue: keyValue)
            collectionView.collectionViewLayout.invalidateLayout()
        }
        return cell
    }
}

extension KeyValuePaginatedCollectionViewDataSource: UICollectionViewDataSourcePrefetching {
    
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
