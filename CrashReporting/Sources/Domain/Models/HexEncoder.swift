//
//  HexEncoder.swift
//  
//
//  Created by Martin Dutra on 29/6/22.
//

import Foundation

class HexEncoder {

    func encode(string: String) -> String? {
        guard let bytes = Data(base64Encoded: string, options: .ignoreUnknownCharacters) else {
            return nil
        }
        let hexDigits = Array("0123456789abcdef".utf16)
        var hexChars = [UTF16.CodeUnit]()
        hexChars.reserveCapacity(bytes.count * 2)
        for byte in bytes {
        let (index1, index2) = Int(byte).quotientAndRemainder(dividingBy: 16)
            hexChars.append(hexDigits[index1])
            hexChars.append(hexDigits[index2])
        }
        return String(utf16CodeUnits: hexChars, count: hexChars.count)
    }
}
