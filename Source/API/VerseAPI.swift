//
//  API+Verse.swift
//  FBTT
//
//  Created by Christoph on 6/7/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

class VerseAPI: API {

    // this is a candidate to be part of API
    enum APIEnvironment {
        case local
        case production
    }

    private var scheme: String
    private var host: String
    private var port: Int

    private init(_ environment: APIEnvironment) {
        switch environment {
            case .local:
                self.scheme = "http"
                self.host = "localhost"
                self.port = 3000
            default:
                self.scheme = "https"
                self.host = Environment.Verse.host
                self.port = 443
        }
    }

    // Don't want to use production?  Change this to .local and rebuild.
    static let api = VerseAPI(.production)

    var headers: APIHeaders = ["planetary-directory-authorize": Environment.Verse.token]

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
