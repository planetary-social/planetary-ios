//
//  NullDirectoryAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class NullDirectoryAPI: DirectoryAPIService {

    static var shared: DirectoryAPIService = NullDirectoryAPI()
    
    // In this implementation we just use in-memory to hold onboarded user
    private var person: Person?
    
    func join(identity: Identity, name: String, birthdate: Date, phone: String, completion: @escaping ((Person?, APIError?) -> Void)) {
        let person = Person(bio: nil,
                             id: "me",
                             identity: identity,
                             image: nil,
                             image_url: nil,
                             in_directory: nil,
                             name: name,
                             shortcode: nil)
        completion(person, nil)
    }
    
    func me(completion: @escaping ((Person?, APIError?) -> Void)) {
        completion(self.person, nil)
    }
   
    func directory(includeMe: Bool, completion: @escaping (([Person], APIError?) -> Void)) {
        if includeMe, let person = self.person, let inDirectory = person.in_directory, inDirectory {
            completion([person], nil)
        } else {
            completion([], nil)
        }
    }

    func directory(show identity: Identity, completion: @escaping ((Bool, APIError?) -> Void)) {
        if let person = self.person, person.identity == identity {
            self.person = Person(bio: person.bio,
                                 id: person.id,
                                 identity: person.identity,
                                 image: person.image,
                                 image_url: person.image_url,
                                 in_directory: true,
                                 name: person.name,
                                 shortcode: person.shortcode)
            completion(true, nil)
        } else {
            completion(false, nil)
        }
    }
   
    func directory(hide identity: Identity, completion: @escaping ((Bool, APIError?) -> Void)) {
        if let person = self.person, person.identity == identity {
            self.person = Person(bio: person.bio,
                                 id: person.id,
                                 identity: person.identity,
                                 image: person.image,
                                 image_url: person.image_url,
                                 in_directory: false,
                                 name: person.name,
                                 shortcode: person.shortcode)
            completion(true, nil)
        } else {
            completion(false, nil)
        }
    }
   
    func directory(offboard identity: Identity, completion: @escaping ((Bool, APIError?) -> Void)) {
        self.person = nil
        completion(true, nil)
    }
    
}
