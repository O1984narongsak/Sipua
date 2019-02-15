//
//  ExtenUIFont.swift
//  SipUa
//
//  Created by NLDeviOS on 14/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import Foundation
import UIKit

extension UIFont {
    class func systemFontSmall() -> UIFont {
        return UIFont(name: "HelveticaNeue", size: 18)!
    }
    
    class func italicSystemNormal() -> UIFont {
        return UIFont(name: "HelveticaNeue-Italic", size: 20)!
    }
    
    class func boldSystemFontBold() -> UIFont {
        return UIFont(name: "HelveticaNeue-Bold", size: 24)!
    }
}
