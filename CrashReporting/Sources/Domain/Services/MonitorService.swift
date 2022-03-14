//
//  MonitorService.swift
//  
//
//  Created by Martin Dutra on 24/11/21.
//

import Foundation

protocol MonitorService {

    func identify(identity: Identity)

    func forget()
    
    func record(_ message: String)

    func report(error: Error, metadata: [AnyHashable: Any]?)

}
