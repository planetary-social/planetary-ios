//
//  DefaultLogsBuilder.swift
//  
//
//  Created by Martin Dutra on 28/6/22.
//

import Foundation
import Logger

class DefaultLogsBuilder: LogsBuilder {

    func build(logger: LogProtocol, identity: Identity?) -> Logs {
        let appLog = buildAppLog(logger: logger)
        var botLog: String?
        if let identity = identity {
            botLog = buildBotLog(identity: identity)
        }
        return Logs(appLog: appLog, botLog: botLog)
    }

    private func buildAppLog(logger: LogProtocol) -> String? {
        guard let logUrl = logger.fileUrls.first else {
            return nil
        }
        do {
            let data = try Data(contentsOf: logUrl)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func buildBotLog(identity: Identity) -> String? {
        // Encode the network key to an HEX string
        guard let networkKeyBytes = Data(base64Encoded: identity.networkKey, options: .ignoreUnknownCharacters) else {
            return nil
        }
        let hexDigits = Array("0123456789abcdef".utf16)
        var hexChars = [UTF16.CodeUnit]()
        hexChars.reserveCapacity(networkKeyBytes.count * 2)
        for byte in networkKeyBytes {
        let (index1, index2) = Int(byte).quotientAndRemainder(dividingBy: 16)
            hexChars.append(hexDigits[index1])
            hexChars.append(hexDigits[index2])
        }
        let hexEncodedNetworkKey = String(utf16CodeUnits: hexChars, count: hexChars.count)

        // Lookup Logs directory for sbot
        let appSupportDirs = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        guard !appSupportDirs.isEmpty else {
            return nil
        }
        let path = appSupportDirs[0].appending("/FBTT").appending("/\(hexEncodedNetworkKey)").appending("/GoSbot/debug")

        // List contents of directory
        let url = URL(fileURLWithPath: path)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [URLResourceKey.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return nil
        }

        // Sort contents by creation date so that the most recent one is the first one
        let sortedURLs = urls.sorted { (lhs, rhs) -> Bool in
            let lhsCreationDate = try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate
            let rhsCreationDate = try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate
            if let lhsCreationDate = lhsCreationDate, let rhsCreationDate = rhsCreationDate {
                return lhsCreationDate.compare(rhsCreationDate) == .orderedDescending
            } else if lhsCreationDate == nil {
                return false
            } else {
                return true
            }
        }

        if sortedURLs.count > 1 {
            do {
                let secondData = try Data(contentsOf: sortedURLs[1])
                let secondLog = String(data: secondData, encoding: .utf8)
                let firstData = try Data(contentsOf: sortedURLs[0])
                if let firstLog = String(data: firstData, encoding: .utf8) {
                    return secondLog?.appending("\n").appending(firstLog)
                }
                return secondLog
            } catch {
                return nil
            }
        } else if sortedURLs.count == 1 {
            do {
                let data = try Data(contentsOf: sortedURLs[0])
                let log = String(data: data, encoding: .utf8)
                return log
            } catch {
                return nil
            }
        }
        return nil
    }
}
