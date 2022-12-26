import Foundation
import secp256k1

public struct KeyPair {
    typealias PrivateKey = secp256k1.Signing.PrivateKey
    typealias PublicKey = secp256k1.Signing.PublicKey
    
    private let privateKey: PrivateKey
    
    var schnorrSigner: secp256k1.Signing.SchnorrSigner {
        return privateKey.schnorr
    }
    
    var schnorrValidator: secp256k1.Signing.SchnorrValidator {
        return privateKey.publicKey.schnorr
    }
    
    public var publicKey: String {
        return Data(privateKey.publicKey.xonly.bytes).hex()
    }
    
    public init() throws {
        privateKey = try PrivateKey()
    }
    
    public init(privateKey: String) throws {
        self = try .init(privateKey: try Data(hex: privateKey))
    }
    
    public init(privateKey: Data) throws {
        self.privateKey = try PrivateKey(rawRepresentation: privateKey)
    }
}
