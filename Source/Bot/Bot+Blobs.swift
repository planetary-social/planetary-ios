//
//  Bot+Blobs.swift
//  Planetary
//
//  Created by Christoph on 11/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Bot {

    func blobsAndDatas(for blobs: Blobs,
                       completion: @escaping (([(Blob, Data)]) -> Void)) {
        Thread.assertIsMainThread()

        guard blobs.count > 0 else { completion([]) ; return }
        var datas: [(Blob, Data)] = []

        for (index, blob) in blobs.enumerated() {
            self.data(for: blob.identifier) {
                _, data, _ in

                // include only if data is not empty
                if let data = data, data.isEmpty == false {
                    datas += [(blob, data)]
                }

                // call completion on last blob
                if index == blobs.count - 1 {
                    completion(datas)
                }
            }
        }
    }
}
