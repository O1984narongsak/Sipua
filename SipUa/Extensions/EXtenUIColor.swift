//
//  EXtenUIColor.swift
//  SipUa
//
//  Created by NLDeviOS on 14/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import Foundation

extension UIColor {
    static let custom_lightGreen = UIColor.init(hexString: "#99b433")
    static let custom_purple = UIColor.init(hexString: "#7e3878")
    static let custom_teal = UIColor.init(hexString: "#00aba9")
    static let custom_darkBlue = UIColor.init(hexString: "#2b5797")
    static let custom_red = UIColor.init(hexString: "#ee1111")
    static let custom_black = UIColor.init(hexString: "#202020")
    static let custom_white = UIColor.init(hexString: "#ffffff")
    
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt32()
        Scanner(string: hex).scanHexInt32(&int)
        let a, r, g, b: UInt32
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    
}
