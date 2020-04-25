//
//  BlobCache.swift
//  FBTT
//
//  Created by Christoph on 6/23/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class BlobCache: DictionaryCache {

    // MARK: Lifecycle

    override init() {
        super.init()
        self.registerNotifications()
    }

    deinit {
        self.deregisterNotifications()
    }

    // MARK: Request UIImage blob

    // TODO https://app.asana.com/0/0/1152660926488309/f
    // TODO make UIImageCompletionHandle opaque for image(for:completion)
    typealias UIImageCompletion = ((BlobIdentifier, UIImage) -> Void)
    typealias UIImageCompletionHandle = UUID

    /// Immediately returns the cached image for the identifier.  This will
    /// not request to load the image from the bot, use `image(for:completion)` instead.
    func image(for identifier: BlobIdentifier) -> UIImage? {
        //Thread.assertIsMainThread()
        return self.item(for: identifier) as? UIImage
    }

    /// Asynchronously returns the cached image for the identifier, or requests the
    /// bot to load the blob.  If the bot has stored the blob locally, it will return the
    /// blob data.  If the bot does not have the blob, it will be requested from the network.
    /// If it eventually gets the blob, the bot will notify `didLoadBlob()` and if there
    /// are any completions for that identifier, they will be called.
    ///
    /// The returned completion handle can be used later to "forget" the completion.  This
    /// is useful for views that are re-used, like table view cells, to manage how many
    /// elements are waiting for a particular blob.
    @discardableResult
    func image(for identifier: BlobIdentifier,
               completion: @escaping UIImageCompletion) -> UIImageCompletionHandle?
    {
        //Thread.assertIsMainThread()

        // returns the cached image immediately
        if let image = self.item(for: identifier) as? UIImage {
            completion(identifier, image)
            return nil
        }

        // otherwise schedule the completion
        let uuid = self.add(completion, for: identifier)

        // start request if there is not a pending one
        if self.completions(for: identifier).count == 1 {
            self.loadImage(for: identifier)
        }

        // wait for load
        return uuid
    }

    private func loadImage(for identifier: BlobIdentifier) {

        Analytics.trackLoad(identifier)
        
        Bots.current.data(for: identifier) {
            [weak self] identifier, data, error in
            guard let me = self else { return }

            // wait if blob unavailable
            if me.blobUnavailable(error, for: identifier) {
                Analytics.trackAppDidLoad(identifier, error: .notAvailable)
                return
            }

            // forget if blob is still unavailable
            // will be requested again if necessary
            guard let data = data, data.isEmpty == false else {
                me.forgetCompletions(for: identifier)
                Analytics.trackAppDidLoad(identifier, error: .emptyData)
                return
            }

            // forget if blob is not an image
            guard let image = UIImage(data: data) else {
                me.forgetCompletions(for: identifier)
                Analytics.trackAppDidLoad(identifier, error: .notImageData)
                return
            }

            // only complete if valid image
            me.update(image, for: identifier)
            me.didLoad(image, for: identifier)
            me.purge()
            Analytics.trackAppDidLoad(identifier)
            Analytics.trackDidLoad(identifier)
        }
    }

    /// Returns true if the specified Error is a blob unavailablee error.
    private func blobUnavailable(_ error: Error?,
                                 for identifier: BlobIdentifier) -> Bool
    {
        // check that error is blob unavailable
        if let error = error as? BotError, error == .blobUnavailable {
            return true
        }

        // otherwise the error is something else
        return false
    }

    private func didLoad(_ image: UIImage,
                         for identifier: BlobIdentifier)
    {
        let completions = self.completions(for: identifier)
        self.forgetCompletions(for: identifier)

        completions.forEach {
            (uuid, completion) in
            completion(identifier, image)
        }
    }

    // MARK: UIImage completions

    // the number of pending blob identifiers to be loaded
    var numberOfBlobIdentifiers: Int {
        return self.completions.count
    }

    // the TOTAL number of completions for all blob identifiers
    // if this is larger than `numberOfBlobIdentifiers` then that
    // means there are multiple requests for the same blob
    var numberOfBlobCompletions: Int {
        var count: Int = 0
        for element in self.completions {
            count += element.value.count
        }
        return count
    }

    // for each blob identifier, there are one or more UUID tagged UIImage completion blocks
    private var completions: [BlobIdentifier: [UUID: UIImageCompletion]] = [:]

    /// Adds a single completion for a specific blob identifier.  Returns a UUID which can
    /// be used to forget a pending completion later.
    private func add(_ completion: @escaping UIImageCompletion,
                     for identifier: BlobIdentifier) -> UUID
    {
        var completions = self.completions(for: identifier)
        let uuid = UUID()
        completions[uuid] = completion
        self.completions[identifier] = completions
        return uuid
    }

    private func completions(for identifier: BlobIdentifier) -> [UUID: UIImageCompletion] {
        return self.completions[identifier] ?? [:]
    }

    /// Forgets all completions for all blob identifiers.
    func forgetCompletions() {
        self.completions.removeAll()
    }

    /// Forgets the all the completions for the specified blob identifier.
    func forgetCompletions(for identifier: BlobIdentifier) {
        let _ = self.completions.removeValue(forKey: identifier)
    }

    /// Forgets a specific UUID tagged completion for a blob identifier.  This will
    /// remove a single completion at a time.
    func forgetCompletions(with uuid: UUID,
                           for identifier: BlobIdentifier)
    {
        // remove completions per UUID
        var completions = self.completions(for: identifier)
        completions.removeValue(forKey: uuid)

        // if no completions left then remove blob identifier
        if completions.isEmpty {
            self.completions.removeValue(forKey: identifier)
        }

        // otherwise update identifier with remaining completions
        else {
            self.completions[identifier] = completions
        }
    }

    // MARK: Cache bytes and purging

    override func bytes(for item: Any) -> Int {
        if let image = item as? UIImage { return image.numberOfBytes }
        return 0
    }

    // the max number of bytes that will trigger a purge
    // the min number of bytes that will remain after a purge
    private let maxNumberOfBytes: Int = (1024 * 1024 * 100)
    private let minNumberOfBytes: Int = (1024 * 1024 * 50)

    // tracks the total bytes in use
    private var bytes: Int = 0

    /// Increments the number of bytes used by the cache.
    private func update(_ image: UIImage, for identifier: Identifier) {
        self.bytes += self.bytes(for: image)
        super.update(image, for: identifier)
    }

    /// Removes cached images, starting with the oldest last recently used LRU, down to
    /// to the configured minimum.
    override func purge() {

        // nothing to do if not enough bytes
        guard self.bytes > self.maxNumberOfBytes else {
            return
        }

        // remember the stats for tracking
        let from = (count: self.count, numberOfBytes: self.bytes)
        var to = (count: 0, numberOfBytes: 0)

        // loop through oldest items first
        let items = self.itemsSortedByDateAscending()
        for item in items.enumerated() {

            // remove expired item
            self.invalidateItem(for: item.element.key)

            // update stats
            to.count += 1
            to.numberOfBytes = self.bytes

            // done if below minimum bytes
            if self.bytes < self.minNumberOfBytes {
                Analytics.trackPurge(.blob,
                                     from: from,
                                     to: to)
                return
            }
        }
    }

    /// Removes the specified item and updates the count and number of bytes.
    override func invalidateItem(for key: String) {
        guard let item = self.item(for: key) else { return }
        self.bytes -= self.bytes(for: item)
        super.invalidateItem(for: key)
    }

    /// Resets the number of bytes and clears all cached items.
    override func invalidate() {
        Analytics.trackPurge(.blob,
                             from: (count: self.count, numberOfBytes: self.bytes),
                             to: (count: 0, numberOfBytes: 0))
        self.bytes = 0
        super.invalidate()
    }

    // MARK: Notifications

    private func registerNotifications() {
        NotificationCenter.default.addObserver(forName: .didLoadBlob,
                                               object: nil,
                                               queue: OperationQueue.main)
        {
            [weak self] notification in
            self?.didLoadBlob(notification)
        }
    }

    private func deregisterNotifications() {
        NotificationCenter.default.removeObserver(self,
                                                  name: .didLoadBlob,
                                                  object: nil)
    }

    private func didLoadBlob(_ notification: Notification) {
        //Thread.assertIsMainThread()
        guard let identifier = notification.blobIdentifier else { return }
        guard self.completions(for: identifier).isEmpty == false else { return }
        self.loadImage(for: identifier)
    }
}

extension UIImage {

    var numberOfBytes: Int {
        guard let image = self.cgImage else { return 0 }
        return image.bytesPerRow * image.height
    }
}
