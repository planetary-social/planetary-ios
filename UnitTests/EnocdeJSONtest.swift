import Multipart
import UIKit
import XCTest

//extension Dictionary {
//
//    // extract uiimage pairs
//    func splitValues() -> ([String: Any], [String: UIImage]) {
//
//        var json: [String: Any] = [:]
//        var images: [String: UIImage] = [:]
//
//        // loop through all keys and find values that are UIImage
//        for key in self.keys {
//            let value = self[key]
//            if value is UIImage {
//                images[key] = value
//            } else {
//                json[key] = value
//            }
//        }
//
//        return (json, images)
//    }
//}

class EncodingTests: XCTestCase {

    func test_dictionaryAndImageToMultipartData() {

        let json = ["in_directory": false]
        guard let jsonData = json.data() else { return }

        let image = UIColor.random().image(dimension: 1)
        guard let imageData = image.pngData() else { return }

        var message = Multipart(type: .formData)
        message.append(Part.FormData(name: "json", fileData: jsonData, fileName: nil, contentType: MIMEType.json.rawValue))
        message.append(Part.FormData(name: "image", fileData: imageData, fileName: nil, contentType: MIMEType.png.rawValue))

        guard let url = URL(string: "https://test.com") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setMultipartBody(message)

        NSLog("\(String(data: request.httpBody!, encoding: .ascii) ?? "no body")")
    }

    func test_dataAndMimeTypeToMultipartData() {

        let json = ["in_directory": false]
        guard let jsonData = json.data() else { return }

        let image = UIColor.random().image(dimension: 1)
        guard let imageData = image.pngData() else { return }

        let body: [(String, Data, MIMEType)] = [("json", jsonData, MIMEType.json),
                                                ("avatar", imageData, MIMEType.png)]

        var multipart = Multipart(type: .formData)
        for (name, data, type) in body {
            let part = Part.FormData(name: name, fileData: data, fileName: nil, contentType: type.rawValue)
            multipart.append(part)
        }

        guard let url = URL(string: "https://test.com") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setMultipartBody(multipart)

        NSLog("\(String(data: request.httpBody!, encoding: .ascii) ?? "no body")")
    }

    /* This test ensure that JSON string literals are correctly escaped \0x0A gets converted to '\\n'etc
     * Swift is correctly handling this (as far as we know) but keep the test to ensure
     * we don't do something custom in the future that breaks this.
     https://spec.scuttlebutt.nz/feed/datamodel.html#signing-encoding-strings
     */
    func test01_jsonpost() {
        
        let texts = [
            "576f756c646e1974206974206265205f6e6963655f0a2e2e2e", // newline and accent
            "426c65657020626c6f6f702061696ee28099740a0a4e6f2066756e0a0af09f98a9",
        ]
        
        let want = [
            "{\"type\":\"post\",\"text\":\"Wouldn\\u0019t it be _nice_\\n...\"}",
            "{\"type\":\"post\",\"text\":\"Bleep bloop ain’t\\n\\nNo fun\\n\\n😩\"}",
        ]
        
        
        for (i,text) in texts.enumerated() {
            
        
            let p = Post(text: stringFromHex(hex: text))
            do {
                let d = try p.encodeToData()
                
                let dbg = String(data: d, encoding: .utf8)
                XCTAssertEqual(dbg!, want[i], "case \(i) failed")
            } catch {
                XCTFail("case \(i) failed")
                XCTAssertNil(error)
            }
        }
    }
}

fileprivate func stringFromHex(hex: String) -> String {
    var hex = hex
    var data = Data()
    while(hex.count > 0) {
        let c: String = hex.substring(to: hex.index(hex.startIndex, offsetBy: 2))
        hex = hex.substring(from: hex.index(hex.startIndex, offsetBy: 2))
        var ch: UInt32 = 0
        Scanner(string: c).scanHexInt32(&ch)
        var char = UInt8(ch)
        data.append(&char, count: 1)
    }
    return String(data: data, encoding: .utf8)!
}
