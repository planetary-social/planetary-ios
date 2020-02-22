//
//  Array+ElementsAtIndexes.swift
//  FBTT
//
//  Created by Christoph on 5/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Array {

    func elements(at indexes: [Index]) -> [Element] {
        var elements: [Element] = []
        for index in indexes {
            guard let element = self[safe: index] else { continue }
            elements += [element]
        }
        return elements
    }
}
