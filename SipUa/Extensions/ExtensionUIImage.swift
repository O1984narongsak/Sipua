//
//  ExtensionUIImage.swift
//  SipUa
//
//  Created by NLDeviOS on 15/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit

@IBDesignable
class UXImage : UIImageView {
    
    // @IBInspectable to make it can adjust in attribute inspector
    // Compute properties with default value 0
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            self.layer.cornerRadius = cornerRadius
        }
    }
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            self.layer.borderWidth = borderWidth
        }
    }
    @IBInspectable var borderColor: UIColor = UIColor.clear {
        didSet {
            self.layer.borderColor = borderColor.cgColor
        }
    }
}
