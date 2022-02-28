//
//  APIService.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation

protocol APIService {

    var isEnabled: Bool { get }

    func identify(identity: Identity)
    func identify(statistics: Statistics)
    func forget()
    func track(event: String, params: [String: Any]?)

}
