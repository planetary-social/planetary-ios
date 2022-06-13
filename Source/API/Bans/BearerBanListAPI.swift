//
//  BearerBanListAPI.swift
//  Planetary
//
//  Created by H on 19.06.20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

enum BearerBanListAPIError: Error {
    case invalidApiPath
    case missingCloudAPISecret
}

/// An object that fetches the official ban list from Planetary's cloud API.
class BearerBanListAPI: BanListAPIService {

    private var scheme: String
    private var host: String
    private var port: Int
    private var pathPrefix: String

    init() {
        if CommandLine.arguments.contains("use-ci-network") {
            print("WARNING: setup block-list as another project")
            self.scheme = "http"
            self.host = "localhost"
            self.port = 80
            self.pathPrefix = ""
        } else {
            self.scheme = "https"
            self.host = "us-central1-pub-verse-app.cloudfunctions.net"
            self.port = 443
            self.pathPrefix = ""
        }
    }

    /// Fetches the ban list on behalf of the given user.
    func retreiveBanList(for identity: FeedIdentifier) async throws -> BanList {
        let bearerToken = try await TokenStore.shared.tokenString(for: identity)
        let authHeader = ["X-Planetary-Bearer-Token": bearerToken]
        let data = try await get(path: "/block-list", headers: authHeader)
        return try JSONDecoder().decode(BanList.self, from: data)
    }
}

extension BearerBanListAPI: API {
    
    var headers: APIHeaders {
        [:] // just here to implement API...
    }

    func send(
        method: APIMethod,
        path: String,
        query: [URLQueryItem],
        body: Data?,
        headers: APIHeaders?,
        completion: @escaping APICompletion
    ) {
        assert(query.isEmpty || body == nil, "Cannot use query and body at the same time")
        guard path.beginsWithSlash else { completion(nil, .invalidPath(path)); return }

        var components = URLComponents()
        components.scheme = self.scheme
        components.host = self.host
        components.path = "\(self.pathPrefix)\(path)"
        components.port = self.port
        
        guard let url = components.url else { completion(nil, .invalidURL); return }

        var request = URLRequest(url: url)
        if let headers = headers { request.add(headers) }
        request.httpMethod = method.rawValue
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            let apiError = response?.httpStatusCodeError ?? APIError.optional(error)
            completion(data, apiError)
        }
        .resume()
    }
}
