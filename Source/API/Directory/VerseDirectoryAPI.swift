//
//  VerseDirectoryAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Keys

class VerseDirectoryAPI: DirectoryAPIService {
    
    static var shared: DirectoryAPIService = VerseDirectoryAPI()
    
    private var scheme: String
    private var host: String
    private var port: Int
    private var token: String
    private var directoryPath: String
    
    init() {
        let keys = PlanetaryKeys()
        self.scheme = "https"
        self.host = "us-central1-pub-verse-app.cloudfunctions.net"
        self.port = 443
        self.token = keys.verseDirectoryAPIToken
        self.directoryPath = "mainnet-directory"
    }
    
    func join(identity: Identity, name: String, birthdate: Date, phone: String, completion: @escaping ((Person?, APIError?) -> Void)) {
        let json: [String: Any] =
            ["birthday": birthdate,
             "identity": identity,
             "phonenumber": phone,
             "name": name,
             "using_plural": true,
             "verified_phone": true]
        self.post(path: "/\(self.directoryPath)/people", json: json) {
            data, error in
            completion(data?.person(), error)
        }
    }
    
    func me(completion: @escaping ((Person?, APIError?) -> Void)) {
        guard let identity = Bots.current.identity else {
            completion(nil, .invalidIdentity)
            return
        }
        let headers: APIHeaders = ["X-Identity": identity]
        self.get(path: "/\(self.directoryPath)/me", query: [], headers: headers) {
            me, error in
            completion(me?.person(), error)
        }
    }
    
    func directory(includeMe: Bool, completion: @escaping (([Person], APIError?) -> Void)) {
        let per_page = URLQueryItem(name: "per_page", value: "1000")
        self.get(path: "/\(self.directoryPath)/", query: [per_page]) {
            data, error in
            var people = data?.persons() ?? []
            people = people.filter { $0.name.isValidName }
            if !includeMe {
                let me = Bots.current.identity
                people = people.filter { $0.identity != me }
            }
            completion(people, error)
        }
    }
    
    func directory(show identity: Identity, completion: @escaping ((Bool, APIError?) -> Void)) {
        // TODO https://app.asana.com/0/1109616169284147/1135482214678101/f
        // TODO ticket for parameter name casing
        let path = "/\(self.directoryPath)/people/"
        let json: [String: Any] = ["Identity": identity,
                                   "in_directory": true]

        self.post(path: path, json: json) {
            _, error in
            completion(error == nil, error)
        }
    }
    
    func directory(hide identity: Identity, completion: @escaping ((Bool, APIError?) -> Void)) {
        // TODO https://app.asana.com/0/1109616169284147/1135482214678101/f
        // TODO ticket for parameter name casing
        let path = "/\(self.directoryPath)/people/"
        let json: [String: Any] = ["Identity": identity,
                                   "in_directory": false]

        self.post(path: path, json: json) {
            _, error in
            completion(error == nil, error)
        }
    }
    
    func directory(offboard identity: Identity, completion: @escaping ((Bool, APIError?) -> Void)) {
        // TODO https://app.asana.com/0/1109616169284147/1135482214678101/f
        // TODO ticket for parameter name casing
        let path = "/\(self.directoryPath)/people/"
        let json: [String: Any] = ["Identity": identity,
                                   "in_directory": false,
                                   "offboarded": true]

        self.post(path: path, json: json) {
            _, error in
            completion(error == nil, error)
        }
    }
    

}

extension VerseDirectoryAPI: API {
    
    var headers: APIHeaders {
        return ["planetary-directory-authorize": self.token]
    }
    
    func send(method: APIMethod,
              path: String,
              query: [URLQueryItem] = [],
              body: Data? = nil,
              headers: APIHeaders? = nil,
              completion: @escaping APICompletion)
    {
        assert(Thread.isMainThread)
        guard path.beginsWithSlash else { completion(nil, .invalidPath(path)); return }

        guard var components = URLComponents(string: path) else { completion(nil, .invalidPath(path)); return }
        components.scheme = self.scheme
        components.host = self.host
        components.port = self.port
        components.queryItems = query
        guard let url = components.url else { completion(nil, .invalidURL); return }

        var request = URLRequest(url: url)
        request.add(self.headers)
        if let headers = headers { request.add(headers) }
        request.httpMethod = method.rawValue
        request.httpBody = body

        // TODO decoding may need to happen on this queue
        URLSession.shared.dataTask(with: request) {
            data, response, error in
            let apiError = response?.httpStatusCodeError ?? APIError.optional(error)
            DispatchQueue.main.async { completion(data, apiError) }
            Log.optional(apiError, from: response)
        }.resume()
    }
    
}
