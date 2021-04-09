//
//  VersePubAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Keys

class VersePubAPI: PubAPIService {
    
    private var scheme: String
    private var host: String
    private var port: Int
    private var token: String
    private var pathPrefix: String
    
    init() {
        let keys = PlanetaryKeys()
        if CommandLine.arguments.contains("use-ci-network") {
            self.scheme = "https"
            self.host = "pub.verse.app"
            self.port = 8443
            self.token = "KrztmpEgK0LEX0yseDBfccgWaxTVZIl/bJOZPjkXV+ArUlP9m5te1cUjQKyc0YuH48"
            self.pathPrefix = ""
        } else {
            self.scheme = "https"
            self.host = "us-central1-pub-verse-app.cloudfunctions.net"
            self.port = 443
            self.token = keys.versePubAPIToken
            self.pathPrefix = "/FollowbackAfterOnboardingTest"
        }
    }
    
    func pubsAreOnline(completion: @escaping ((Bool, APIError?) -> Void)) {
        self.get(path: "/v1/ping") { data, error in
            completion(data?.isPong() ?? false, error)
        }
    }
    
    func invitePubsToFollow(_ identity: Identity, completion: @escaping ((Bool, APIError?) -> Void)) {
        let headers: APIHeaders = ["Verse-New-Key": identity]
        self.get(path: "/v1/invite", headers: headers) { data, error in
            Log.optional(error)
            completion(error == nil, error)
        }
    }

}

extension VersePubAPI: API {
    
    var headers: APIHeaders {
        return ["Verse-Authorize-Pub": self.token]
    }

    func send(method: APIMethod, path: String, query: [URLQueryItem], body: Data?, headers: APIHeaders?, completion: @escaping APICompletion) {
        assert(Thread.isMainThread)
        assert(query.isEmpty || body == nil, "Cannot use query and body at the same time")
        guard path.beginsWithSlash else { completion(nil, .invalidPath(path)); return }

        var components = URLComponents()
        components.scheme = self.scheme
        components.host = self.host
        components.path = "\(self.pathPrefix)\(path)"
        components.port = self.port
        
        guard let url = components.url else { completion(nil, .invalidURL); return }

        var request = URLRequest(url: url)
        request.add(self.headers)
        if let headers = headers { request.add(headers) }
        request.httpMethod = method.rawValue
        request.httpBody = body

        URLSession.shared.dataTask(with: request) {
            data, response, error in
            let apiError = response?.httpStatusCodeError ?? APIError.optional(error)
            DispatchQueue.main.async { completion(data, apiError) }
            Log.optional(apiError, from: response)
        }.resume()
    }
}

// MARK:- Custom decoding

fileprivate extension Data {

    func isPong() -> Bool {
        guard let pong = String(data: self, encoding: .utf8) else { return false }
        return pong.contains("pong")
    }
}
