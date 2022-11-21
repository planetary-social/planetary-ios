//
//  DatabaseConnectionPool.swift
//  Planetary
//
//  Created by Matthew Lorentz on 11/21/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

final class DatabaseConnectionPool: Sendable {
    private var _isOpen = false
    private var openConnections = [Connection]()
    private var lock = NSLock()
    
    var isOpen: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isOpen
    }
    
    func open() {
        lock.withLock { _isOpen = true }
    }
    
    func close() async {
        lock.withLock { _isOpen = false }
        while !openConnections.isEmpty {
            lock.withLock {
                openConnections.removeAll(where: { CFGetRetainCount($0) <= 3 })
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50 milliseconds
        }
    }
    
    func checkout() throws -> Connection? {
        lock.lock()
        defer { lock.unlock() }
        guard _isOpen else { throw ViewDatabaseError.notOpen }
            
        return openConnections.first(where: { CFGetRetainCount($0) <= 3 })
    }
    
    func add(_ connection: Connection) throws {
        lock.lock()
        defer { lock.unlock() }
        guard _isOpen else { throw ViewDatabaseError.notOpen }
        openConnections.append(connection)
    }
}
