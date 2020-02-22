//
//  PushAPI.swift
//  FBTT
//
//  Created by Christoph on 8/12/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

class PushAPI: API {

    var headers: APIHeaders = ["planetary-push-authorize": Environment.Push.token]
    let host = Environment.Push.host

    private init() {}
    static let api = PushAPI()

    func send(method: APIMethod,
              path: String,
              query: [URLQueryItem] = [],
              body: Data? = nil,
              headers: APIHeaders? = nil,
              completion: @escaping APICompletion)
    {
        assert(Thread.isMainThread)
        assert(query.isEmpty || body == nil, "Cannot use query and body at the same time")
        guard path.beginsWithSlash else { completion(nil, .invalidPath(path)); return }

        var components = URLComponents()
        components.scheme = "https"
        components.host = self.host
        components.path = path
        components.port = 443

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

extension PushAPI {

    static func update(_ token: Data?,
                       for identity: Identity,
                       completion: @escaping ((Bool, APIError?) -> Void))
    {
        var json: [String: Any] = ["identity": identity]
        if let token = token { json["token"] = token.hexEncodedString() }
        json["environment"] = Environment.Push.environment

        self.api.post(path: "/apns-service/apns", json: json) {
            _, error in
            completion(error == nil, error)
        }
    }
}

fileprivate extension Data {

    // Borrowed from Stack Overflow
    // https://stackoverflow.com/questions/8798725/get-device-token-for-push-notification
    func hexEncodedString() -> String {
        let string = self.reduce("", {$0 + String(format: "%02X", $1)})
        return string
    }
}
