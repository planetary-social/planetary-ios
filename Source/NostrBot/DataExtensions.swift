import Foundation

private extension Collection {
    func unfoldSubSequences(ofMaxLength maxSequenceLength: Int) -> UnfoldSequence<SubSequence, Index> {
        sequence(state: startIndex) { current in
            guard current < endIndex else { return nil }
            
            let upperBound = index(current, offsetBy: maxSequenceLength, limitedBy: endIndex) ?? endIndex
            defer { current = upperBound }
            
            return self[current..<upperBound]
        }
    }
}

extension Data {
    enum DecodingError: Error {
        case oddNumberOfCharacters
        case invalidHexCharacters([Character])
    }
    
    func hex() -> String {
        return self.map { String(format: "%02hhx", $0) }.joined()
    }
    
    init(hex: String) throws {
        guard hex.count.isMultiple(of: 2) else { throw DecodingError.oddNumberOfCharacters }
        
        self = .init(capacity: hex.utf8.count / 2)

        for pair in hex.unfoldSubSequences(ofMaxLength: 2) {
            guard let byte = UInt8(pair, radix: 16) else {
                let invalidCharacters = Array(pair.filter({ !$0.isHexDigit }))
                throw DecodingError.invalidHexCharacters(invalidCharacters)
            }
            
            append(byte)
        }
    }
}
