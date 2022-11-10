//
//  Draft.swift
//  Planetary
//
//  Created by Martin Dutra on 10/20/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

// Mark AttributedString as @Sendable for now, because it just hasn't been in the standard library yet, but it's a
// value type so it shoudl be safe.
#if compiler(>=5.5) && canImport(_Concurrency)
extension AttributedString: @unchecked Sendable {}
#endif

/// A class representing a drafted post. Supports NSCoding so it can be saved to disk.
class Draft: NSObject, NSCoding {
    
    var attributedText: NSAttributedString?
    var images: [UIImage] = []
    
    init(attributedText: NSAttributedString?, images: [UIImage]) {
        self.attributedText = attributedText
        self.images = images
    }
    
    // swiftlint:disable legacy_objc_type
    required init?(coder: NSCoder) {
        self.attributedText = coder.decodeObject(of: NSAttributedString.self, forKey: "attributedText")
        self.images = (coder.decodeObject(of: NSArray.self, forKey: "images") as? [UIImage]) ?? []
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(attributedText, forKey: "attributedText")
        coder.encode(images, forKey: "images")
    }
    // swiftlint:enable legacy_objc_type
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let otherDraft = object as? Draft else {
            return false
        }
        
        return otherDraft.attributedText == attributedText && otherDraft.images == images
    }
}

actor DraftStore {
    
    let userDefaults: UserDefaults
    let draftKey: String
    var lastSavedDraft: Draft?
    
    init(userDefaults: UserDefaults = .standard, draftKey: String) {
        self.userDefaults = userDefaults
        self.draftKey = draftKey
    }
    
    func loadDraft() -> Draft? {
        if let draftData = userDefaults.data(forKey: draftKey),
            let draft = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(draftData) as? Draft {
            lastSavedDraft = draft
            return draft
        }
        
        return nil
    }
    
    func save(text string: AttributedString?, images: [UIImage]) {
        let draft = Draft(
            attributedText: string.map { NSAttributedString($0) },
            images: images
        )
        
        // optimization since encoding is expensive
        guard draft != lastSavedDraft else {
            return
        }
        
        lastSavedDraft = draft
        let data = try? NSKeyedArchiver.archivedData(withRootObject: draft, requiringSecureCoding: false)
        userDefaults.set(data, forKey: draftKey)
        userDefaults.synchronize()
    }
    
    func clearDraft() {
        lastSavedDraft = nil
        userDefaults.removeObject(forKey: draftKey)
        userDefaults.synchronize()
    }
}
