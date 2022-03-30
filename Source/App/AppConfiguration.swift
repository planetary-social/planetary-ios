//
//  AppConfiguration.swift
//  FBTT
//
//  Created by Christoph on 3/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

/// Represents the set of high-level properties governing the app, like the user's identity, network key, etc.
/// These configurations can be switched out at runtime much like logging in/out of an account.
///
/// The AppConfiguration is stored in the keychain, protecting the user's secret key in case of database corruption.
/// A single device can have many AppConfigurations (see the extensions to the `AppConfigurations` typealias) but only
/// one can be in use at a time.
///
/// The AppConfiguration is also used to prevent feed forks in some cases by storing the number of published messages.
class AppConfiguration: NSObject, NSCoding {

    // MARK: Editable properties

    var name: String = "New configuration"
    
    /// The number of messages this user has published. This number is used to prevent the user from publishing before
    /// their feed has fully synced, which "forks" or breaks it forever.
    /// Should be kept up-to-date by the `Bot`.
    var numberOfPublishedMessages: Int = 0

    private var networkDidChange = false
    var network: NetworkKey? {
        didSet {
            self.networkDidChange = true
        }
    }

    private var secretDidChange = false
    var secret: Secret? {
        didSet {
            self.secretDidChange = true
        }
    }

    private var botDidChange = false
    var bot: Bot? {
        didSet {
            self.botDidChange = true
        }
    }

    // MARK: Calculated properties

    // Note that this is based on the configured network key.
    // Any non-SSB network must have a non-nil value.
    var hmacKey: HMACKey? {
        get {
            if self.network == NetworkKey.ssb { return nil } else if self.network == NetworkKey.integrationTests { return HMACKey.integrationTests } else if self.network == NetworkKey.verse { return HMACKey.verse } else if self.network == NetworkKey.planetary { return HMACKey.planetary } else { return _hmacKey }
        }
        set {
            _hmacKey = newValue
        }
    }
    private var _hmacKey: HMACKey?

    // Alias property for `hmacKey`
    var signingKey: HMACKey? {
        self.hmacKey
    }

    var identity: Identity? {
        self.secret?.identity
    }

    var canLaunch: Bool {
        self.network != nil &&
            self.identity != nil &&
            self.secret != nil &&
            self.bot != nil
    }

    // MARK: Lifecycle

    override init() {}

    convenience init(with secret: Secret) {
        self.init()
        self.setDefaultName()
        self.secret = secret
        self.bot = Bots.bot(named: "GoBot")
    }

    required init?(coder aDecoder: NSCoder) {
        guard let name = aDecoder.decodeObject(forKey: "name") as? String else { return nil }
        self.name = name
        if let data = aDecoder.decodeObject(forKey: "network") as? Data { self.network = NetworkKey(base64: data) } else { self.network = nil }
        if let named = aDecoder.decodeObject(forKey: "bot") as? String { self.bot = Bots.bot(named: named) } else { self.bot = nil }
        if let string = aDecoder.decodeObject(forKey: "secret") as? String { self.secret = Secret(from: string) }
        if aDecoder.containsValue(forKey: "numberOfPublishedMessages") {
            self.numberOfPublishedMessages = aDecoder.decodeInteger(forKey: "numberOfPublishedMessages")
        }
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.name, forKey: "name")
        if let secret = self.secret { aCoder.encode(secret.jsonString(), forKey: "secret") }
        if let network = self.network { aCoder.encode(network.data, forKey: "network") }
        if let bot = self.bot { aCoder.encode(bot.name, forKey: "bot") }
        aCoder.encode(numberOfPublishedMessages, forKey: "numberOfPublishedMessages")
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let configuration = object as? AppConfiguration else { return false }
        return configuration.name == self.name && configuration.identity == self.identity
    }
}

extension AppConfiguration {

    static var hasCurrent: Bool {
        AppConfiguration.current != nil
    }

    static var needsToBeCreated: Bool {
        AppConfiguration.current == nil
    }
    
    static var needsToBeLoggedOut: Bool {
        #if DEBUG
        return false
        #else
        return AppConfiguration.current?.network != NetworkKey.ssb
        #endif
    }

    var isCurrent: Bool {
        self.identity == AppConfiguration.current?.identity
    }

    static func isCurrent(_ identity: Identity) -> Bool {
        guard let configuration = self.current else { return false }
        return configuration.identity == identity
    }
}

extension AppConfiguration {

    func setDefaultName(_ name: String? = nil) {
        let dateString = DateFormatter.localizedString(from: Date(),
                                                       dateStyle: .short,
                                                       timeStyle: .short)
        self.name = "\(name ?? "") \(dateString)"
    }
}

typealias AppConfigurations = [AppConfiguration]
