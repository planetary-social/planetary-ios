//
//  VersePushAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import Secrets

class VersePushAPI: PushAPIService {
    
    private var scheme: String
    private var host: String
    private var port: Int
    private var token: String?
    private var environment: String
    
    init() {
        self.scheme = "https"
        self.host = "us-central1-pub-verse-app.cloudfunctions.net"
        self.port = 443
        self.token = Keys.shared.get(key: .push)
        #if DEBUG
        self.environment = "development"
        #else
        self.environment = "production"
        #endif
    }
    
    func update(_ token: Data?, for identity: Identity, completion: @escaping ((Bool, APIError?) -> Void)) {
        var json: [String: Any] = ["identity": identity]
        if let token = token {
            json["token"] = token.hexEncodedString()
        }
        json["environment"] = self.environment

        self.post(path: "/apns-service/apns", json: json) { _, error in
            completion(error == nil, error)
        }
    }
}

// MARK: API
extension VersePushAPI: API {
    
    var headers: APIHeaders {
        if let token = self.token {
            return ["planetary-push-authorize": token]
        } else {
            return [:]
        }
    }
    
    func send(method: APIMethod, path: String, query: [URLQueryItem], body: Data?, headers: APIHeaders?, completion: @escaping APICompletion) {
        assert(Thread.isMainThread)
        assert(query.isEmpty || body == nil, "Cannot use query and body at the same time")
        guard path.beginsWithSlash else { completion(nil, .invalidPath(path)); return }

        var components = URLComponents()
        components.scheme = self.scheme
        components.host = self.host
        components.path = path
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

// MARK: Util
fileprivate extension Data {

    // Borrowed from Stack Overflow
    // https://stackoverflow.com/questions/8798725/get-device-token-for-push-notification
    func hexEncodedString() -> String {
        let string = self.reduce("", { $0 + String(format: "%02X", $1) })
        return string
    }
}
