//
//  DirectoryAPIService.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

protocol DirectoryAPIService {
    
    static var shared: DirectoryAPIService { get }
    
    // Onboards a new identity in the directory
    func join(identity: Identity, name: String, birthdate: Date, phone: String, completion: @escaping ((Person?, APIError?) -> Void))
    
    // Get current person
    func me(completion: @escaping ((Person?, APIError?) -> Void))
    
    // Returns the list of people in the directory
    func directory(includeMe: Bool, completion: @escaping (([Person], APIError?) -> Void))
 
    // Make the current person visible in the directory
    func directory(show identity: Identity, completion: @escaping ((Bool, APIError?) -> Void))
    
    // Make the current person invisible in the directory
    func directory(hide identity: Identity, completion: @escaping ((Bool, APIError?) -> Void))
    
    // Offboards an identity in the directory
    func directory(offboard identity: Identity, completion: @escaping ((Bool, APIError?) -> Void))
    
}
