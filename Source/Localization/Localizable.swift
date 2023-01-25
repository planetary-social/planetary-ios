import Foundation
import SwiftUI

protocol Localizable {
    var template: String { get }

    /// optionally override this to provide your own key
    var key: String { get }

    /// optionally override this to provide your own namespace key
    /// defaults to the type name of the enum
    static var namespace: String { get }
    
    /// Creates a SwiftUI Text view for this text.
    var view: Text { get }

    static func exportForStringsFile() -> String
}

//    Use as follows:
//
//    enum Text: String, Localizable {
//        case hello = "Hello!"
//        case greeting = "Hello {{ name }}!"
//    }
//
//    Text.hello.text
//        Hello!
//
//    Text.greeting.text(["name": "friend"])
//        Hello friend!
//
//    To create a localizable strings file, you can conform your enum to CaseIterable,
//    and then call the following:
//
//    Text.exportForStringsFile()
//        "Text.hello" = "Hello.";
//        "Text.greeting" = "Hello {{ name }}.";
//
//    Then simply implement localization in the `text` function:
//
//        var text: String {
//            return NSLocalizedString(key, comment: "")
//        }
//
extension Localizable {
    
    // You can modify this to perform localization, or overrides based on server or other config
    var text: String {
        let bundle = Bundle(for: CurrentBundle.self)
        let string = NSLocalizedString(key, tableName: "Generated", bundle: bundle, value: "not_found", comment: "")
        if string == "not_found" {
            if let path = bundle.path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: path) {
                return bundle.localizedString(forKey: key, value: nil, table: "Generated")
            } else {
                return string
            }
        } else {
            return string
        }
    }

    // replaces keys in the string with values from the dictionary passed
    // case greeting = "Hello {{ name }}."
    // greeting.text(["name": ]) -> Hello
    func text(_ arguments: [String: String]) -> String {
        do {
            var text = self.text
            for (key, value) in arguments {
                let regex = try NSRegularExpression(pattern: "\\{\\{\\s*\(key)\\s*\\}\\}", options: .caseInsensitive)
                text = regex.stringByReplacingMatches(
                    in: text, options: NSRegularExpression.MatchingOptions(rawValue: 0),
                    range: NSRange(location: 0, length: text.count), withTemplate: value
                )
            }
            return text
        } catch {
            return ""
        }
    }

    var uppercased: String {
        text.uppercased()
    }

    static var namespace: String {
        String(describing: self)
    }
    
    var view: Text {
        Text(text)
    }
    
    func view(_ arguments: [String: String]) -> Text {
        Text(text(arguments))
    }

    var key: String {
        "\(Self.namespace).\(String(describing: self))"
    }

    // escape newlines in templates, used when exporting templates for Localizable.strings
    var escapedTemplate: String {
        template.replacingOccurrences(of: "\n", with: "\\n")
    }
}

extension Localizable {
    var description: String {
        text
    }
}

extension Localizable where Self: RawRepresentable, Self.RawValue == String {
    var template: String {
        rawValue
    }
}

extension Localizable where Self: CaseIterable {
    static func exportForStringsFile() -> String {
        let list = allCases.map { text in
            "\"\(text.key)\" = \"\(text.escapedTemplate)\";"
        }
        return list.joined(separator: "\n")
    }
}

private class CurrentBundle {}
