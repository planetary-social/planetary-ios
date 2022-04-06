//
//  API.swift
//  FBTT
//
//  Created by Christoph on 6/5/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

enum APIMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}

typealias APIHeaders = [String: String]

extension APIHeaders {

    static let jsonContentType = ["Content-Type": MIMEType.json.rawValue]
}

typealias APICompletion = ((Data?, APIError?) -> Void)

protocol API {

    var headers: APIHeaders { get }

    func send(method: APIMethod,
              path: String,
              query: [URLQueryItem],
              body: Data?,
              headers: APIHeaders?,
              completion: @escaping APICompletion)
}

extension API {

    // MARK: Get

    func get(path: String,
             query: [URLQueryItem] = [],
             headers: APIHeaders? = nil,
             completion: @escaping APICompletion) {
        self.send(method: .GET,
                  path: path,
                  query: query,
                  body: nil,
                  headers: headers,
                  completion: completion)
    }

    // MARK: Put

    func put(path: String,
             query: [URLQueryItem],
             completion: @escaping APICompletion) {
        self.send(method: .PUT,
                  path: path,
                  query: query,
                  body: nil,
                  headers: nil,
                  completion: completion)
    }

    func put(path: String,
             json: [String: Any],
             completion: @escaping APICompletion) {
        guard let data = json.data() else { completion(nil, .encodeError); return }
        self.send(method: .PUT,
                  path: path,
                  query: [],
                  body: data,
                  headers: nil,
                  completion: completion)
    }

    // TODO https://app.asana.com/0/914798787098068/1135510648157743/f
    // TODO need MIME type too
    func put(path: String,
             body: Data,
             completion: @escaping APICompletion) {
        self.send(method: .PUT,
                  path: path,
                  query: [],
                  body: body,
                  headers: nil,
                  completion: completion)
    }

    // MARK: Post

    func post(path: String,
              query: [URLQueryItem],
              completion: @escaping APICompletion) {
        self.send(method: .POST,
                  path: path,
                  query: query,
                  body: nil,
                  headers: nil,
                  completion: completion)
    }

    func post(path: String,
              json: [String: Any],
              completion: @escaping APICompletion) {
        guard let data = json.data() else { completion(nil, .encodeError); return }
        self.send(method: .POST,
                  path: path,
                  query: [],
                  body: data,
                  headers: APIHeaders.jsonContentType,
                  completion: completion)
    }

    // MARK: Delete

    func delete(path: String,
                query: [URLQueryItem] = [],
                completion: @escaping APICompletion) {
        self.send(method: .DELETE,
                  path: path,
                  query: query,
                  body: nil,
                  headers: nil,
                  completion: completion)
    }
}

// TODO necessary?
extension String {

    var beginsWithSlash: Bool {
        self.hasPrefix("/")
    }
}
