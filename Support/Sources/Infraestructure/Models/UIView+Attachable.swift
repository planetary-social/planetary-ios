//
//  File.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation
import UIKit
import SupportSDK

extension UIView {

    func requestAttachment() -> RequestAttachment? {
        guard let data = self.jpegData() else {
            return nil
        }
        let date = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .short,
            timeStyle: .short)
        return RequestAttachment(filename: date,
                                 data: data,
                                 fileType: .jpg)
    }

    

}
