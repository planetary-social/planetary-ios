# Multipart

A simple library for creating multipart-encoded message bodies.

## Integration

#### Swift Package Manager

You can use [The Swift Package Manager](https://swift.org/package-manager) by adding the proper description to your `Package.swift` file:

```swift
// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "YOUR_PROJECT_NAME",
    dependencies: [
        .package(url: "https://github.com/Fyrts/Multipart.git", from: "0.1"),
    ]
)
```
Then run `swift build`.

#### Manually

To use this library in your project, drag Multipart.xcodeproj into your workspace.

## Usage

#### Creating simple multipart messages

```swift
import Multipart

var message = Multipart(type: .alternative)
message.append(Part(body: "Lorem ipsum dolor sit amet.", contentType: "text/plain"))
message.append(Part(body: "<p><b>Lorem ipsum</b> dolor sit <i>amet</i>.</p>", contentType: "text/html"))
print(message)
```

#### Creating advanced multipart messages

```swift
import Multipart

// Construct a multipart/alternative message
var plainTextPart = Part(body: "Lorem ipsum dolor sit amet.".data(using: .ascii)!)
plainTextPart.setValue("text/plain", forHeaderField: "Content-Type")
plainTextPart.setAttribute(attribute: "charset", value: "us-ascii", forHeaderField: "Content-Type")

var htmlPart = Part(body: "<p><b>Lorem ipsum</b> dolor sit <i>amet</i>.</p>")
htmlPart.setValue("text/html", forHeaderField: "Content-Type")
htmlPart.setAttribute(attribute: "charset", value: "utf-8", forHeaderField: "Content-Type")

let textParts = Multipart(type: .alternative, parts: [plainTextPart, htmlPart])

// Add a file by wrapping it in a multipart/mixed message
var filePart = Part(body: "Ut enim ad minim veniam, quis nostrud exercitation ullamco.")
filePart.setValue("text/plain", forHeaderField: "Content-Type")
filePart.setAttribute(attribute: "charset", value: "utf-8", forHeaderField: "Content-Type")
filePart.setValue("attachment", forHeaderField: "Content-Disposition")
filePart.setAttribute(attribute: "filename", value: "attachment.txt", forHeaderField: "Content-Disposition")

var mixedMessage = Multipart(type: .mixed, parts: [textParts, filePart])
mixedMessage.preamble = "This is a multi-part message in MIME format."

print(mixedMessage)
```

#### Sending form data

`Part.FormData` is a helper function for quickly building `multipart/form-data` messages, while `URLRequest.setMultipartBody`
provides simple means of sending the data over HTTP. 

```swift
import Multipart

var message = Multipart(type: .formData)
message.append(Part.FormData(name: "firstname", value: "Johnny"))
message.append(Part.FormData(name: "lastname", value: "Appleseed"))

var request = URLRequest(url: URL(string: "https://example.com")!)
request.httpMethod = "POST"
request.setMultipartBody(message)

URLSession.shared.dataTask(with: request) { data, response, error in
    print(data, response, error)
}.resume()
```

#### Uploading files

`Part.FormData` also provides basic file upload functionality.

```swift
import Multipart

let fileContents = try! Data(contentsOf: URL(string: "/Users/user/Desktop/document.pdf")!)

var message = Multipart(type: .formData)
message.append(Part.FormData(name: "message", value: "See attached file."))
message.append(Part.FormData(name: "file", fileData: fileContents, fileName: "document.pdf", contentType: "application/pdf"))

var request = URLRequest(url: URL(string: "https://example.com")!)
request.httpMethod = "POST"
request.setMultipartBody(message)

URLSession.shared.dataTask(with: request) { data, response, error in
    print(data, response, error)
}.resume()
```

#### Sending multipart messages manually

If `URLRequest.setMultipartBody` does not suit your needs, you can use `Multipart.headers` and `Multipart.body` to construct a
request yourself.

```swift
import Multipart

var message = Multipart(type: .formData)
message.append(Part.FormData(name: "firstname", value: "Johnny"))
message.append(Part.FormData(name: "lastname", value: "Appleseed"))

var request = URLRequest(url: URL(string: "https://example.com")!)
request.httpMethod = "POST"

for header in message.headers {
    request.setValue(header.valueWithAttributes, forHTTPHeaderField: header.name)
}
request.httpBody = message.body
```
