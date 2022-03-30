//
//  AuthyPhoneVerificationAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import Secrets

class AuthyPhoneVerificationAPI: PhoneVerificationAPIService {
    
    private var token: String?
    
    init() {
        self.token = Keys.shared.get(key: .authy)
    }
    
    func requestCode(country: String, phone: String, completion: @escaping ((PhoneVerificationResponse?, APIError?) -> Void)) {
        let path = "https://api.authy.com/protected/json/phones/verification/start"
        var items = [URLQueryItem(name: "via", value: "sms")]
        items += [URLQueryItem(name: "code_length", value: "6")]
        items += [URLQueryItem(name: "country_code", value: country)]
        items += [URLQueryItem(name: "locale", value: "en")]
        items += [URLQueryItem(name: "phone_number", value: phone)]
        self.post(path: path, query: items) { data, error in
            completion(data?.authyResponse(), APIError.optional(error))
        }
    }
    
    func verifyCode(_ code: String, country: String, phone: String, completion: @escaping ((PhoneVerificationResponse?, APIError?) -> Void)) {
        let path = "https://api.authy.com/protected/json/phones/verification/check"
        var items = [URLQueryItem(name: "country_code", value: country)]
        items += [URLQueryItem(name: "phone_number", value: phone)]
        items += [URLQueryItem(name: "verification_code", value: code)]
        self.get(path: path, query: items) { data, error in
            completion(data?.authyResponse(), APIError.optional(error))
        }
    }
}

// MARK: API
extension AuthyPhoneVerificationAPI: API {
    
    var headers: APIHeaders {
        if let token = self.token {
            return ["X-Authy-API-Key": token]
        } else {
            return [:]
        }
    }
    
    func send(method: APIMethod, path: String, query: [URLQueryItem], body: Data?, headers: APIHeaders?, completion: @escaping APICompletion) {
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

// MARK: Util
fileprivate extension Data {

    func authyResponse() -> PhoneVerificationResponse? {
        try? JSONDecoder().decode(PhoneVerificationResponse.self, from: self)
    }
}
