//
//  APIService.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation

protocol APIService {

    func identify(identity: Identity)

    func forget()

    func record(_ message: String)

    func report(error: Error, metadata: [AnyHashable: Any]?)
    
}
