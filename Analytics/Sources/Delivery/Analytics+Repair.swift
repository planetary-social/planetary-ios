//
//  Analytics+Repair.swift
//  
//
//  Created by Martin Dutra on 12/1/22.
//

import Foundation

public extension Analytics {

    func trackDidRepair(function: String) {
        service.track(event: .did, element: .app, name: "repair", param: "function", value: function)
    }

}
