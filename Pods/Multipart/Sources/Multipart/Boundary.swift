import Foundation

/// Defines a random string that can be used as boundary in MIME-encoded messages.
struct Boundary {
    
    let stringValue: String
    
    var delimiter: String { return "--" + self.stringValue }
    var distinguishedDelimiter: String { return self.delimiter + "--" }
    
    var delimiterData: Data { return self.delimiter.data(using: .utf8)! }
    var distinguishedDelimiterData: Data { return self.distinguishedDelimiter.data(using: .utf8)! }
    
    init() {
        self.stringValue = (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
    }
    
}
