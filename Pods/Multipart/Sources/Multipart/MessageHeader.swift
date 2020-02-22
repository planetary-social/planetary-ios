import Foundation

/// A message header for use with multipart entities and subparts.
public struct MessageHeader {
    
    /// Header name like "Content-Type".
    public let name: String
    
    /// Header value, not including attributes.
    public var value: String
    
    /// Header attributes like "name" or "filename".
    public var attributes: [String: String]
    
    /// Complete header value, including attributes.
    public var valueWithAttributes: String {
        get {
            var strings = [self.value]
            for attribute in self.attributes {
                if let attributeValue = attribute.value.addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed) {
                    strings.append("\(attribute.key)=\"\(attributeValue)\"")
                }
            }
            return strings.joined(separator: "; ")
        }
    }
    
    public init(name: String, value: String, attributes: [String:String] = [:]) {
        self.name = name
        self.value = value
        self.attributes = attributes
    }
    
    /// Return complete header including name, value and attributes. Does not include line break.
    public func string() -> String {
        return "\(self.name): \(self.valueWithAttributes)"
    }
}

// Array helper functions
extension Array where Iterator.Element == MessageHeader {
    subscript(key: String) -> MessageHeader? {
        get {
            return self.first(where: {$0.name == key})
        }
        set {
            if let index = self.index(where: {$0.name == key}) {
                self.remove(at: index)
                if let newValue = newValue {
                    self.insert(newValue, at: index)
                }
            } else if let newValue = newValue {
                self.append(newValue)
            }
        }
    }
    
    public mutating func remove(_ key: String) {
        if let index = self.index(where: {$0.name == key}) {
            self.remove(at: index)
        }
    }
    
    /// Return all headers as a single string, each terminated with a line break.
    public func string() -> String {
        return self.map { header -> String in
            return header.string() + Multipart.CRLF
        }.joined()
    }
    
    /// Return all headers, each terminated with a line break.
    public func data(using encoding: String.Encoding = .utf8) -> Data? {
        return self.string().data(using: encoding)
    }
}
