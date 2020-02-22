import Foundation

/// A message part that can be added to Multipart containers.
public struct Part: MultipartEntity {
    
    /// Complete message body
    public var body: Data
    
    /// Message headers that apply to this specific part
    public var headers: [MessageHeader] = []
    
    public init(body: Data, contentType: String? = nil) {
        self.body = body
        
        if let contentType = contentType {
            self.setValue(contentType, forHeaderField: "Content-Type")
        }
    }
    
    public init(body: String, contentType: String? = nil) {
        self.init(body: body.data(using: .utf8) ?? Data(), contentType: contentType)
        self.setAttribute(attribute: "charset", value: "utf-8", forHeaderField: "Content-Type")
    }

}

// Helper functions for quick generation of "multipart/form-data" parts.
extension Part {
    
    /// A "multipart/form-data" part containing a form field and its corresponding value, which can be added to
    /// Multipart containers.
    /// - Parameter name: Field name from the form.
    /// - Parameter value: Value from the form field.
    public static func FormData(name: String, value: String) -> Part {
        var part = Part(body: value)
        part.setValue("form-data", forHeaderField: "Content-Disposition")
        part.setAttribute(attribute: "name", value: name, forHeaderField: "Content-Disposition")
        return part
    }
    
    /// A "multipart/form-data" part containing file data, which can be added to Multipart containers.
    /// - Parameter name: Field name from the form.
    /// - Parameter fileData: Complete contents of the file.
    /// - Parameter fileName: Original local file name of the file.
    /// - Parameter contentType: MIME Content-Type specifying the nature of the data.
    public static func FormData(name: String, fileData: Data, fileName: String? = nil, contentType: String? = nil) -> Part {
        var part = Part(body: fileData)
        part.setValue("form-data", forHeaderField: "Content-Disposition")
        part.setAttribute(attribute: "name", value: name, forHeaderField: "Content-Disposition")
        if let fileName = fileName {
            part.setAttribute(attribute: "filename", value: fileName, forHeaderField: "Content-Disposition")
        }
        if let contentType = contentType {
            part.setValue(contentType, forHeaderField: "Content-Type")
        }
        return part
    }
}

extension Part {
    public var description: String {
        var descriptionString = self.headers.string() + Multipart.CRLF
        if let string = String(data: self.body, encoding: .utf8) {
            descriptionString.append(string)
        } else {
            descriptionString.append("(\(self.body.count) bytes)")
        }
        return descriptionString
    }
}
