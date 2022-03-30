// this file is executed during the Run Phase in a Run Script action
// it is not to be included in an app target.

extension Text {
    static func writeFiles(to path: String, locale primaryLocale: String = "en", translations: [String] = []) {
        let stringsFileName = "Generated.strings"
        let dir = NSURL(fileURLWithPath: FileManager().currentDirectoryPath + path, isDirectory: true)

        guard let primaryLocation = dir.appendingPathComponent("\(primaryLocale).lproj/\(stringsFileName)") else { return }

        let stringsText = localizableTypes.map { $0.exportForStringsFile() }.joined(separator: "\n\n")

        let primaryText = "// This file is auto-generated at build time and should not be modified by hand\n\n\(stringsText)"

        write(text: primaryText, file: primaryLocation)

        for locale in translations {
            guard let translationFile = dir.appendingPathComponent("\(locale).lproj/\(stringsFileName)") else { return }
            var translatedStrings = stringsText

            // here we want to export our new strings and remove unused strings
            // without removing already translated strings
            if let translatedContent = try? String(contentsOf: translationFile) {
                var existingTranslations = [String: String]()

                for line in translatedContent.components(separatedBy: "\n") {
                    if let key = line.components(separatedBy: " = ").first {
                        existingTranslations[key] = line
                    }
                }

                let lines = stringsText.components(separatedBy: "\n")
                let newLines: [String] = lines.map { line in
                    if let key = line.components(separatedBy: " = ").first {
                        return existingTranslations[key] ?? line
                    } else {
                        // not a line with a translation, either empty or a comment
                        return line
                    }
                }

                translatedStrings = newLines.joined(separator: "\n")
            }

            var translatedText = "// This file is auto-generated at build time\n"
            translatedText += "// Existing translations are left in place, and new keys are added as needed\n\n"
            translatedText += translatedStrings
            write(text: translatedText, file: translationFile)
        }
    }

    static func write(text: String, file: URL) {
        try? FileManager().createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.write(to: file, atomically: true, encoding: .utf8)
    }
}

Text.writeFiles(to: "/Source/Localization", locale: "en", translations: [
    "af-ZA",
    "ar-SA",
    "ca-ES",
    "cs-CZ",
    "da-DK",
    "de-DE",
    "el-GR",
    "en-US",
    "en",
    "es-AR",
    "es-ES",
    "es-UY",
    "es",
    "fi-FI",
    "fr-FR",
    "he-IL",
    "hu-HU",
    "it-IT",
    "ja-JP",
    "ko-KR",
    "mi-NZ",
    "nl-NL",
    "no-NO",
    "pl-PL",
    "pl",
    "pt-BR",
    "pt-PT",
    "ro-RO",
    "ru-RU",
    "sr-SP",
    "sv-SE",
    "tr-TR",
    "uk-UA",
    "vi-VN",
    "zh-CN",
    "zh-TW",
])
