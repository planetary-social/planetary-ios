//
//  TestAPI.swift
//  FBTTAPITests
//
//  Created by Henry Bubert on 05.08.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

class TestAPI: PubAPI {
    static let shared = TestAPI()

    override init() {
        super.init()
        super.headers = ["Verse-Authorize-Pub": "KrztmpEgK0LEX0yseDBfccgWaxTVZIl/bJOZPjkXV+ArUlP9m5te1cUjQKyc0YuH48"]
        super.httpPort = 8443
        super.httpHost = "pub.verse.app"
        super.httpPathPrefix = ""
    }

    func onboarded(who identity: Identity,
                          name: String? = nil,
                          image: BlobIdentifier? = nil,
                          messageCount: Int = -1,
                          follows: String? = nil,
                          completion: @escaping PubAPIOnboardedTestCompletion) {
        var headers: APIHeaders = [ "Verse-New-Key": identity ]
        var wantName = false
        if let n = name {
            headers.updateValue(n, forKey: "Verse-Test-Name")
            wantName = true
        }
        var wantImage = false
        if let i = image {
            headers.updateValue(i, forKey: "Verse-Test-Image")
            wantImage = true
        }
        var wantFollows = false
        if let f = follows {
            headers.updateValue(f, forKey: "Verse-Test-Follows")
            wantFollows = true
        }
        self.get(path: "/v2/test/onboarded", headers: headers) {
            data, error in
            guard let d = data else {
                let e = GoBotError.duringProcessing("error from onboarded API endpoint", error ?? APIError.decodeError)
                completion(nil, APIError.other(e))
                return
            }
            if let e = error {
                let body = String(data: d, encoding: .utf8)
                print("TestAPI returned: \(body ?? "<nil>")")
                completion(nil, e)
                return
            }

            do {
                let res = try JSONDecoder().decode(OnboardedResult.self, from: d)

                if messageCount > 0 && res.All < messageCount {
                    completion(nil, APIError.other(GoBotError.unexpectedFault("less messages then expected: \(res.All)")))
                    return
                }

                if wantName && !res.GotName {
                    completion(nil, APIError.other(GoBotError.unexpectedFault("did not get name")))
                    return
                }

                if wantImage && !res.GotImage {
                    completion(nil, APIError.other(GoBotError.unexpectedFault("did not get image")))
                    return
                }

                if wantFollows && !res.GotFollows {
                    completion(nil, APIError.other(GoBotError.unexpectedFault("did not match follows")))
                    return
                }

                completion(res, nil)
            } catch {
                completion(nil, APIError.optional(error))
            }
        }
    }

    func letTestPubUnfollow(_ identity: Identity,
                            completion: @escaping PubAPICompletion) {
        let headers: APIHeaders = ["Verse-New-Key": identity]
        self.get(path: "/v2/test/unfollow", headers: headers) {
            _, error in
            completion(error == nil, error)
        }
    }

    func blockedStart(_ testUser: Identity, completion: @escaping ((Identity, Error?) -> Void)) {
        self.post(path: "/v3/test/blocked/start", json: ["TestUser": testUser]) {
            data, err in
            if let e = err {
                guard let d = data else {
                    completion("@in.valid", e)
                    return
                }
                let body = String(data: d, encoding: .utf8) ?? "<no body>"
                completion("@invalid", GoBotError.duringProcessing(body, e))
                return
            }

            guard let d = data else {
                let e = GoBotError.duringProcessing("error from onboarded blocked/start endpoint", err ?? APIError.decodeError)
                completion("@error", APIError.other(e))
                return
            }

            var res: BlockedBotStartResult?
            do {
                res = try JSONDecoder().decode(BlockedBotStartResult.self, from: d)
            } catch {
                completion("@error", error)
            }

            if !res!.started {
                completion("@apifailure", GoBotError.unexpectedFault("bot not started?!"))
                return
            }

            print("TestAPI \(res!.msg): (new ID: \(res!.newid)")
            completion(res!.newid, nil)
        }
    }

    // tells the test-runner that the bot is now blocked.
    // it checks for the block message on the graph
    // it also makes the blockbot sync to verify it doesn't get new messages from the author
    // the bot then publishes a few new messages to make sure they don't end up on the authors bot
    func blockedBlocked(bot: Identity,
                     author: Identity,
                        seq: Int,
                        ref: MessageIdentifier,
                 completion: @escaping ErrorCompletion) {
        let params: [String: Any] = [
            "Bot": bot,
            "Author": author,
            "Sequence": seq,
            "LatestRef": ref,
        ]
        self.post(path: "/v3/test/blocked/blocked", json: params) {
            data, error in
            var err: Error? = error
            var body = ""
            if let d = data {
                body = String(data: d, encoding: .utf8) ?? "<no body>"
                print("testAPI/blocked/blocked: \(body)")
                if let e = error {
                    err = GoBotError.duringProcessing(body, e)
                }
            }
            completion(err)
        }
    }

    func blockedUnblocked(bot: Identity,
                      author: Identity,
                         seq: Int,
                         ref: MessageIdentifier,
                  completion: @escaping ErrorCompletion) {
        let params: [String: Any] = [
            "Bot": bot,
            "Author": author,
            "Sequence": seq,
            "LatestRef": ref,
        ]
        self.post(path: "/v3/test/blocked/unblocked", json: params) {
            data, error in
            var err: Error? = error
            var body = ""
            if let d = data {
                body = String(data: d, encoding: .utf8) ?? "<no body>"
                print("testAPI/blocked/unblocked: \(body)")
                if let e = error {
                    err = GoBotError.duringProcessing(body, e)
                }
            }
            completion(err)
        }
    }

    func blockedStop(bot: Identity, completion: @escaping ErrorCompletion) {
        self.post(path: "/v3/test/blocked/stop", json: ["Bot": bot]) {
            data, error in
            var err: Error? = error
            var body = ""
            if let d = data {
                body = String(data: d, encoding: .utf8) ?? "<no body>"
                print("testAPI/blocked/stop: \(body)")
                if let e = error {
                    err = GoBotError.duringProcessing(body, e)
                }
            }
            completion(err)
        }
    }
}

typealias PubAPIOnboardedTestCompletion = ((OnboardedResult?, APIError?) -> Void)
struct OnboardedResult: Codable {
    // message counts
    let All: Int
    let About: Int
    let Contact: Int
    let Unknown: Int

    // did the requsted matches work
    var GotName: Bool
    var GotImage: Bool
    var GotFollows: Bool
}

private struct BlockedBotStartResult: Codable {
    let started: Bool
    let msg: String
    let newid: Identity
}
