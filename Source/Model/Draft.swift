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
final class Draft: NSObject, NSCoding, Sendable {
    
    let text: String
    let images: [UIImage]
    
    init(text: String, images: [UIImage]) {
        self.text = text
        self.images = images
    }
    
    // swiftlint:disable legacy_objc_type
    required init?(coder: NSCoder) {
        self.text = coder.decodeObject(forKey: "text") as? String ?? ""
        self.images = (coder.decodeObject(of: NSArray.self, forKey: "images") as? [UIImage]) ?? []
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(text, forKey: "text")
        coder.encode(images, forKey: "images")
    }
    // swiftlint:enable legacy_objc_type
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let otherDraft = object as? Draft else {
            return false
        }
        
        return otherDraft.text == text && otherDraft.images == images
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

    func save(text string: String, images: [UIImage]) {
        let draft = Draft(
            text: string,
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
