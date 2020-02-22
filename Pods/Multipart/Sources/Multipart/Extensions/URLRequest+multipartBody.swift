import Foundation

extension URLRequest {
    /// Set multipart MIME data as the message body of the request, such as for an HTTP POST request.
    /// - Parameter multipart: the multipart MIME body to send
    public mutating func setMultipartBody(_ multipart: Multipart) {
        for header in multipart.headers {
            self.setValue(header.valueWithAttributes, forHTTPHeaderField: header.name)
        }
        self.httpBody = multipart.body
    }
}
