//
//  AuthyAPI.swift
//  FBTT
//
//  Created by Christoph on 6/14/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias AuthyCompletion = ((AuthyResponse?, APIError?) -> Void)

class AuthyAPI: API {

    private init() {}

    var headers: APIHeaders = ["X-Authy-API-Key": Environment.Authy.token]

    func send(method: APIMethod,
              path: String,
              query: [URLQueryItem] = [],
              body: Data? = nil,
              headers: APIHeaders? = nil,
              completion: @escaping APICompletion)
    {
        assert(Thread.isMainThread)
        assert(method == .GET || method == .POST, "AuthyAPI only supports GET or POST")
        assert(body == nil, "AuthyAPI does not support body data")
        assert(headers == nil, "AuthyAPI does not support additional headers")

        guard var components = URLComponents(string: path) else { completion(nil, .invalidPath(path)); return }
        components.queryItems = query
        guard let url = components.url else { completion(nil, .invalidURL); return }

        var request = URLRequest(url: url)
        request.add(self.headers)
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

extension AuthyAPI {

    static private let api = AuthyAPI()

    static func requestCode(country: String,
                            phone: String,
                            completion: @escaping AuthyCompletion)
    {
        let path = "https://api.authy.com/protected/json/phones/verification/start"
        var items = [URLQueryItem(name: "via", value: "sms")]
        items += [URLQueryItem(name: "code_length", value: "6")]
        items += [URLQueryItem(name: "country_code", value: country)]
        items += [URLQueryItem(name: "locale", value: "en")]
        items += [URLQueryItem(name: "phone_number", value: phone)]
        self.api.post(path: path, query: items) {
            data, error in
            completion(data?.authyResponse(), APIError.optional(error))
        }
    }

    static func verifyCode(_ code: String,
                           country: String,
                           phone: String,
                           completion: @escaping AuthyCompletion)
    {
        let path = "https://api.authy.com/protected/json/phones/verification/check"
        var items = [URLQueryItem(name: "country_code", value: country)]
        items += [URLQueryItem(name: "phone_number", value: phone)]
        items += [URLQueryItem(name: "verification_code", value: code)]
        self.api.get(path: path, query: items) {
            data, error in
            completion(data?.authyResponse(), APIError.optional(error))
        }
    }
}

struct AuthyResponse: Codable {
    let message: String
    let success: Bool
    let uuid: String?
}

fileprivate extension Data {

    func authyResponse() -> AuthyResponse? {
        return try? JSONDecoder().decode(AuthyResponse.self, from: self)
    }
}
