//
//  TokenStore.swift
//  Planetary
//
//  Created by H on 19.06.20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Secrets

enum TokenStoreError: Error {
    case invalidApiPath
    case missingCloudAPISecret
}

/// An object requests and stores bearer tokens used for authentication when talking to Planetary's cloud services.
actor TokenStore {

    static let shared = TokenStore()
    
    private static let apiPath = "https://us-central1-pub-verse-app.cloudfunctions.net/bearer-token-service/request-new-token"
    private let keys = Keys.shared
    private var cachedCredentials: BearerCredentials?
    
    /// Credentials needed to access Planetary's cloud services.
    struct BearerCredentials: Codable {
        var token: String
        var expires: Date
        var identity: FeedIdentifier
    }

    /// Fetches the bearer token for the given identity. If one is cached then it will be returned immediately,
    /// otherwise a new one will be requested.
    func tokenString(for identity: FeedIdentifier) async throws -> String {
        if let currentCredentials = cachedCredentials,
           currentCredentials.identity == identity,
           Date.now < currentCredentials.expires {
            return currentCredentials.token
        } else {
            let newCredentials = try await newBearerToken(for: identity)
            cachedCredentials = newCredentials
            return newCredentials.token
        }
    }
    
    /// Fetches a fresh bearer token from the authentication API.
    private func newBearerToken(for identity: FeedIdentifier) async throws -> BearerCredentials {
        guard let url = URL(string: TokenStore.apiPath) else {
            throw TokenStoreError.invalidApiPath
        }
        
        guard let clientSecret = keys.get(key: .planetaryCloudAPISecret) else {
            throw TokenStoreError.missingCloudAPISecret
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(clientSecret, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{\"identity\": \"\(identity)\" }".data(using: .utf8)
        let (responseData, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(BearerCredentials.self, from: responseData)
    }
}
