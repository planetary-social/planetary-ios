//
//  BlobCache.swift
//  FBTT
//
//  Created by Christoph on 6/23/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import CrashReporting

enum BlobCacheError: Error {
    case unsupported
    case network(Error?)
}

/// An object that loads image blob data. This class not only caches blobs but also coordinates loading them from
/// backing stores.
///
/// The full blob load process goes something like this:
/// 1. Some piece of UI asks the `BlobCache` for an image.
/// 2. `BlobCache` checks in-memory cache for blob.
/// 3. If the image is not in the cache, we ask GoBot to look for the blob the file system at a deterministic path
/// based on the blob ID
/// 4. If the image is not on the file system we tell go-ssb that we `ssbBlobWant` it.
/// 5. `BlobCache` hits the HTTP blob service to see if it has the blob.
/// 6. If go-ssb is able to get the blob from a peer it calls the swift function `notifyBlobReceived` which posts a
/// notification that `BlobCache` is listening for.
/// 7. `BlobCache` hears the notification and retries step 3.
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
    typealias UIImageCompletion = ((Result<(BlobIdentifier, UIImage), Error>) -> Void)
    typealias UIImageCompletionHandle = UUID

    /// Immediately returns the cached image for the identifier.  This will
    /// not request to load the image from the bot, use `image(for:completion)` instead.
    func image(for identifier: BlobIdentifier) -> UIImage? {
        Thread.assertIsMainThread()
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
    func image(for identifier: BlobIdentifier, completion: @escaping UIImageCompletion) -> UIImageCompletionHandle? {
        Thread.assertIsMainThread()

        // returns the cached image immediately
        if let anyItem = self.item(for: identifier) {
            if let image = anyItem as? UIImage {
                completion(.success((identifier, image)))
            } else {
                completion(.failure(BlobCacheError.unsupported))
            }
            return nil
        }
        
        let requestUUID = UUID()
        
        Task.detached {
            // otherwise schedule the completion
            let isFirstRequest = await self.requestManager.add(completion, for: identifier, uuid: requestUUID)
            
            // start request if there is not a pending one
            if isFirstRequest {
                await MainActor.run {
                    self.loadImage(for: identifier)
                }
            }
        }

        // wait for load
        return requestUUID
    }
    
    /// Same as `image(for identifier:completion:)` except in returns a placeholder image if the blob type is
    /// unsupported.
    @discardableResult
    func imageOrPlaceholder(
        for identifier: BlobIdentifier,
        completion: @escaping (UIImage) -> Void
    ) -> UIImageCompletionHandle? {
        
        image(for: identifier) { result in
            switch result {
            case .success((_, let loadedImage)):
                completion(loadedImage)
            case .failure(let error):
                Log.optional(error)
                completion(UIImage.verse.unsupportedBlobPlaceholder)
            }
        }
    }
    
    /// An async version of `imageOrPlaceholder(for:completion:)`. Does not support cancellation.
    func imageOrPlaceholder(for identifier: BlobIdentifier) async -> UIImage {
        await withCheckedContinuation { continuation in
            self.imageOrPlaceholder(for: identifier) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func loadImage(for identifier: BlobIdentifier) {
        
        Bots.current.data(for: identifier) { [weak self] identifier, data, error in
            guard let self = self else { return }

            // If we don't have the blob downloaded yet ask the Planetary API for it as an optimization.
            if self.isBlobUnavailableError(error) {
                self.loadBlobFromCloud(for: identifier) { result in
                    if let image = try? result.get() {
                        self.didLoad(identifier, result: .success(image))
                    }
                    // If we failed to load from the Planetary API we don't fail so the Bot can keep trying to
                    // fetch images.
                }
                return
            }
            
            // Retry failures
            guard let data = data, data.isEmpty == false, error == nil else {
                if let botError = error as? BotError, case BotError.restoring = botError {
                    // Don't mess with blobs while restoring
                    return
                }
                
                Task.detached {
                    if await self.requestManager.shouldRetry(identifier: identifier) {
                        let delay = await self.requestManager.retryDelay(for: identifier)
                        Log.info("Loading blob \(identifier) failed. Retrying in \(delay) seconds")
                        await self.requestManager.didRetry(identifier: identifier)
                        
                        try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                        
                        await MainActor.run {
                            self.loadImage(for: identifier)
                        }
                    } else {
                        Log.info("Loading blob \(identifier) failed. Reached max retry count")
                    }
                }
                return
            }

            guard let image = UIImage(data: data) else {
                self.didLoad(identifier, result: .failure(BlobCacheError.unsupported))
                return
            }

            // only complete if valid image
            self.didLoad(identifier, result: .success(image))
        }
    }
    
    /// Attempt to load a blob from Planetary's cloud services.
    private func loadBlobFromCloud(
        for blobRef: BlobIdentifier,
        completion: @escaping (Result<UIImage, BlobCacheError>) -> Void
    ) {
        let hexRef = blobRef.hexEncodedString()
        
        // first 2 chars are directory
        let dir = String(hexRef.prefix(2))
        // rest ist filename
        let restIdx = hexRef.index(hexRef.startIndex, offsetBy: 2)
        let rest = String(hexRef[restIdx...])
        
        var gsUrl = URL(string: "https://blobs.planetary.social/")!
        gsUrl.appendPathComponent(dir)
        gsUrl.appendPathComponent(rest)
        
        let dataTask = URLSession.shared.dataTask(with: gsUrl) { [weak self] (data, response, error) in
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                // Nothing to do if data task was cancelled on purpose
                return
            }
            
            Log.optional(error)
            
            guard error == nil,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200,
                let data = data else {
                    completion(.failure(.network(error)))
                return
            }
            
            guard let image = UIImage(data: data) else {
                completion(.failure(.unsupported))
                return
            }
            
            Bots.current.store(data: data, for: blobRef) { (_, error) in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                
                if error == nil {
                    DispatchQueue.main.async {
                        completion(.success(image))
                    }
                }
                
                guard let requestManager = self?.requestManager else {
                    return
                }
                
                Task.detached {
                    await requestManager.removeDataTask(for: blobRef)
                }
            }
        }
        
        Task.detached {
            await self.requestManager.add(dataTask, for: blobRef)
        }
        
        dataTask.resume()
    }

    /// Returns true if the specified Error is a blob unavailable error.
    private func isBlobUnavailableError(_ error: Error?) -> Bool {
        // check that error is blob unavailable
        if let error = error as? BotError, error == .blobUnavailable {
            return true
        }

        // otherwise the error is something else
        return false
    }
    
    private func didLoad(_ identifier: BlobIdentifier, result: Result<UIImage, Error>) {
        Task.detached {
            await MainActor.run {
                if let image = try? result.get() {
                    self.store(image, for: identifier)
                }
            }
            
            let uuidsAndCompletionBlocks = await self.requestManager.popCompletions(for: identifier)
            
            for completion in uuidsAndCompletionBlocks.values {
                await MainActor.run {
                    completion(result.map { (identifier, $0) })
                }
            }
            
            await MainActor.run {
                self.purge()
            }
        }
    }

    // MARK: UIImage completions

    /// An object that manages in-flight requests for blobs.
    private var requestManager = RequestManager()
    
    /// An object that manages in-flight requests for blobs. Structured as an actor to prevent data races.
    actor RequestManager {
        
        /// A map of completion handlers along with their unique IDs and the identifiers of the blobs they are
        /// waiting on.
        private var completions: [BlobIdentifier: [UUID: UIImageCompletion]] = [:]
        
        /// A dictionary that keeps track of how many time we have tried and failed to get a blob.
        private var retries: [BlobIdentifier: Int] = [:]
        private var retryLimit = 5
        
        /// A dictionary of HTTP requests to load blobs and the identifiers of the blobs they have requested.
        private var dataTasks: [BlobIdentifier: URLSessionDataTask] = [:]

        /// The number of pending blob identifiers currently being loaded
        var numberOfBlobIdentifiers: Int {
            return self.completions.count
        }

        // The total number of requests for all blob identifiers
        // if this is larger than `numberOfBlobIdentifiers` then that
        // means there are multiple requests for at least one blob.
        var numberOfBlobCompletions: Int {
            var count: Int = 0
            for element in self.completions {
                count += element.value.count
            }
            return count
        }
        
        func numberOfCompletions(for identifier: BlobIdentifier) -> Int {
            completions[identifier]?.count ?? 0
        }
        
        /// Adds a single completion for a specific blob identifier. Returns true if this is the first request
        /// for the given blob.
        func add(_ completion: @escaping UIImageCompletion, for identifier: BlobIdentifier, uuid: UUID) -> Bool {
            var completions = self.completions[identifier] ?? [:]
            completions[uuid] = completion
            self.completions[identifier] = completions
            return completions.count == 1
        }
        
        /// Removes the completion handlers for the given blob from storage and returns them.
        /// Completions can only be accessed this way externally to prevent handlers from being called twice.
        func popCompletions(for identifier: BlobIdentifier) -> [UUID: UIImageCompletion] {
            let completionsForIdentifier = completions[identifier] ?? [:]
            forgetCompletions(for: identifier)
            return completionsForIdentifier
        }

        /// Forgets all completions for all blob identifiers.
        func forgetCompletions() {
            completions.removeAll()
            cancelAllDataTasks()
        }

        /// Forgets the all the completions for the specified blob identifier.
        func forgetCompletions(for identifier: BlobIdentifier) {
            let _ = self.completions.removeValue(forKey: identifier)
            cancelDataTask(for: identifier)
            retries.removeValue(forKey: identifier)
        }
        
        func add(_ dataTask: URLSessionDataTask, for identifier: BlobIdentifier) {
            dataTasks[identifier] = dataTask
        }
        
        func cancelAllDataTasks() {
            dataTasks.forEach { (_, dataTask) in
                dataTask.cancel()
            }
            dataTasks.removeAll()
        }
        
        func cancelDataTask(for identifier: BlobIdentifier) {
            if let dataTask = dataTasks.removeValue(forKey: identifier) {
                dataTask.cancel()
            }
        }
        
        func removeDataTask(for identifier: BlobIdentifier) {
            dataTasks.removeValue(forKey: identifier)
        }
        /// Forgets a specific UUID tagged completion for a blob identifier.  This will
        /// remove a single completion at a time.
        func forgetCompletions(with uuid: UUID, for identifier: BlobIdentifier) {
            // remove completions per UUID
            var completions = self.completions[identifier] ?? [:]
            completions.removeValue(forKey: uuid)

            // if no completions left then remove blob identifier
            if completions.isEmpty {
                self.completions.removeValue(forKey: identifier)
            }

            // otherwise update identifier with remaining completions
            else {
                self.completions[identifier] = completions
            }
            
            cancelDataTask(for: identifier)
        }
        
        func shouldRetry(identifier: BlobIdentifier) -> Bool {
            retries[identifier] ?? 0 < retryLimit
        }
        
        /// The number of seconds that should be waited before the next retry
        func retryDelay(for identifier: BlobIdentifier) -> Int {
            // this is the only way I could find to convert Decimal to Int
            // swiftlint:disable legacy_objc_type
            NSDecimalNumber(decimal: pow(Decimal(retries[identifier] ?? 0), 2)).intValue
            // swiftlint:enable legacy_objc_type
        }
        
        func didRetry(identifier: BlobIdentifier) {
            let previousRetries = retries[identifier] ?? 0
            retries[identifier] = previousRetries + 1
        }
    }
    
    func forgetCompletions(with uuid: UUID, for identifier: BlobIdentifier) {
        Task.detached {
            await self.requestManager.forgetCompletions(with: uuid, for: identifier)
        }
    }

    // MARK: Cache bytes and purging

    override func bytes(for item: Any) -> Int {
        if let image = item as? UIImage { return image.numberOfBytes }
        return 0
    }

    // the max number of bytes that will trigger a purge
    // the min number of bytes that will remain after a purge
    private let maxNumberOfBytes: Int = (1_024 * 1_024 * 100)
    private let minNumberOfBytes: Int = (1_024 * 1_024 * 50)

    // tracks the total bytes in use
    private var bytes: Int = 0

    /// Inserts the image into the cache and updates the number of bytes used by the cache.
    private func store(_ image: UIImage, for identifier: Identifier) {
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
                Log.info("Purging with count=\(from.count), bytes=\(from.numberOfBytes)")
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
        Log.info("Purging with count=\(self.count), bytes=\(self.bytes)")
        self.bytes = 0
        super.invalidate()
    }

    // MARK: Notifications

    private func registerNotifications() {
        NotificationCenter.default.addObserver(forName: .didLoadBlob,
                                               object: nil,
                                               queue: OperationQueue.main) {
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
        guard let identifier = notification.blobIdentifier else { return }
        Task {
            await MainActor.run {
                self.loadImage(for: identifier)
            }
        }
    }
}

extension UIImage {

    var numberOfBytes: Int {
        guard let image = self.cgImage else { return 0 }
        return image.bytesPerRow * image.height
    }
}
