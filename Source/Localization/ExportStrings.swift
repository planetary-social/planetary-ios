// this file is executed during the Run Phase in a Run Script action
// it is not to be included in an app target.

// swiftlint:disable force_try

typealias TranslationKey = String
typealias Translation = String

extension Localized {
    static func writeFiles(to path: String, locale primaryLocale: String = "en") {
        let stringsFileName = "Generated.strings"
        let directory = NSURL(fileURLWithPath: FileManager().currentDirectoryPath + path, isDirectory: true)

        guard let primaryLocation = directory.appendingPathComponent("\(primaryLocale).lproj/\(stringsFileName)") else {
            return
        }

        let oldPrimaryLocaleStrings = try! String(contentsOf: primaryLocation)
        let newPrimaryLocaleStrings = localizableTypes.map { $0.exportForStringsFile() }.joined(separator: "\n\n")

        /// These are the keys that will be overwritten in the rest of the Generated.strings files.
        let changedKeys = changedKeys(from: oldPrimaryLocaleStrings, to: newPrimaryLocaleStrings)
        let orderedKeys = orderedKeys(fromGeneratedStrings: newPrimaryLocaleStrings)
        
        let primaryText = "// This file is auto-generated at build time and should not be modified by hand\n\n"
            + newPrimaryLocaleStrings

        write(text: primaryText, file: primaryLocation)
    }

    static func write(text: String, file: URL) {
        try? FileManager().createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.write(to: file, atomically: true, encoding: .utf8)
    }
}

/// Converts a Generated.strings file into a dictionary of translation keys and translation strings.
func dictionary(fromGeneratedStrings generatedStrings: String) -> [TranslationKey: Translation] {
    var dict = [TranslationKey: Translation]()
    
    for line in generatedStrings.components(separatedBy: "\n") {
        let components = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true)
        guard components.count == 2 else {
            // comment or blank line
            continue
        }
        
        let trimmedComponents = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let key = trimmedComponents[0]
        let translation = trimmedComponents[1]
        dict[key] = translation
    }
    
    return dict
}

/// Creates an array of translations keys from a Generated.strings file, preserving their order. This is used to keep
/// strings in the same order across all Generated.strings files.
///
/// Empty string are used to signal that a blank line was in the source file, because we want to preserve those too.
func orderedKeys(fromGeneratedStrings generatedStrings: String) -> [TranslationKey] {
    let lines = generatedStrings.components(separatedBy: "\n")
    return lines.compactMap { line in
        let components = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true)
        guard components.count == 2 else {
            // comment or blank line
            return ""
        }
        
        let trimmedComponents = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let key = trimmedComponents[0]
        return key
    }
}

/// Takes two Generates.strings file contents and computes the set of TranslationKeys that were:
/// 1) Added in the new file
/// 2) Removed from the new file
/// 3) Had their translation changed between the old and new files.
func changedKeys(from oldStrings: String, to newStrings: String) -> Set<TranslationKey> {
    let oldKeysAndTranslations = dictionary(fromGeneratedStrings: oldStrings)
    let newKeysAndTranslations = dictionary(fromGeneratedStrings: newStrings)
    var changedKeys = Set(oldKeysAndTranslations.keys).symmetricDifference(Set(newKeysAndTranslations.keys))
    
    // Find any lines where the tranlation changed but they key didn't
    for (oldKey, oldTranslation) in oldKeysAndTranslations {
        if let newTranslation = newKeysAndTranslations[oldKey],
            newTranslation != oldTranslation {
            changedKeys.insert(oldKey)
        }
    }
    
    return changedKeys
}

Localized.writeFiles(to: "/Source/Localization", locale: "en")
