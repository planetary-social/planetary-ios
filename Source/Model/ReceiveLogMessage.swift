import Foundation

struct ReceiveLogMessage: Codable, @unchecked Sendable {

    let key: MessageIdentifier
    let value: MessageValue
    let receiveLogSequence: Int64

}
