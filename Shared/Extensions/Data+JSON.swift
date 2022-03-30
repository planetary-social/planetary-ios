//
//  Data+JSON.swift
//  FBTT
//
//  Created by Christoph on 2/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Data {

    static func fromJSON(resource named: String) -> Data {
        guard let url = Bundle.current.url(forResource: named, withExtension: nil) else { return Data() }
        guard let data = try? Data(contentsOf: url) else { return Data() }
        return data
    }

    // TODO rename and move to own file
    func string() -> String? {
        String(data: self, encoding: .utf8)
    }
}
