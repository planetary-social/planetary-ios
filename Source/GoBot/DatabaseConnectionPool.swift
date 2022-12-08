//
//  DatabaseConnectionPool.swift
//  Planetary
//
//  Created by Matthew Lorentz on 11/21/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SQLite

/// A class that keeps a set of database connections alive and lends them out to callers so they can perform queries.
///
/// The implementation is fairly simple, we are mostly just synchronizing access to an array of connections with a
/// lock. We can tell when a connection is no longer being used by querying its retain count. It would be nice if this
/// object could be refactored as an Actor but that would require making all the functions on ViewDatabase async.
final class DatabaseConnectionPool: Sendable {
    private var _isOpen = false
    private var openConnections = [Connection]()
    private var lock = NSLock()
    
    /// This number is the retain count at which we consider a Connection to no longer be in use. When a caller checks
    /// out a Connection with `checkout()` they will increment the retain count and when they are done using it they
    /// decrement it. The reason this number is more than one is because iterating through the array of connections
    /// causes the retain count to go up as well.
    static let connectionReleaseThreshold = 3
    
    /// Queries whether the connection pool is ready to serve connections. Connections can not be checked out until
    /// the database has been initialized.
    var isOpen: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isOpen
    }
    
    /// Instructs the pool that it should start serving connections.
    func open() {
        lock.withLock { _isOpen = true }
    }
    
    /// Instructs the pool to stop serving connections. This function will block until all open connections have
    /// finished their queries and been closed.
    func close() async {
        lock.withLock { _isOpen = false }
        while !openConnections.isEmpty {
            lock.withLock {
                openConnections.removeAll(where: { CFGetRetainCount($0) <= Self.connectionReleaseThreshold })
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50 milliseconds
        }
    }
    
    /// Requests a connection from the pool. The connection will automatically be returned to the pool when it goes out
    /// of scope. This function will return nil if all connections are already being used. It will throw an error
    /// if the pool is not yet open.
    func checkout() throws -> Connection? {
        lock.lock()
        defer { lock.unlock() }
        guard _isOpen else { throw ViewDatabaseError.notOpen }
            
        return openConnections.first(where: { CFGetRetainCount($0) <= Self.connectionReleaseThreshold })
    }
    
    /// Adds a new connection to the pool.
    func add(_ connection: Connection) throws {
        lock.lock()
        defer { lock.unlock() }
        guard _isOpen else { throw ViewDatabaseError.notOpen }
        openConnections.append(connection)
    }
}
