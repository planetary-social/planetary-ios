//
//  UIView+Data.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation
import UIKit

extension UIView {

    private func image() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()
        return image
    }
    
    func jpegData() -> Data? {
        self.image()?.jpegData(compressionQuality: 0.5)
    }
}
