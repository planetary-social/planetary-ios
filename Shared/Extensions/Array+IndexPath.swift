//
//  Array+IndexPath.swift
//  FBTT
//
//  Created by Christoph on 9/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Array {

    func indexPathForLast() -> IndexPath? {
        guard self.count > 0 else {
            return nil
        }
        
        return IndexPath(row: self.count - 1, section: 0)
    }
}
