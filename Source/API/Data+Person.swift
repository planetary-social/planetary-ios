//
//  Data+Person.swift
//  FBTT
//
//  Created by Christoph on 8/14/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Data {

    func person() -> Person? {
        do {
            return try JSONDecoder().decode(Person.self, from: self)
        } catch {
            return nil
        }
    }

    func persons() -> [Person] {
        do {
            return try JSONDecoder().decode([Person].self, from: self)
        } catch {
            return []
        }
    }
}
