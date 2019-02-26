//
//  ExtensionUIButton.swift
//  SipUa
//
//  Created by NLDeviOS on 15/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit

// @IBDesignable to make change in interface builder (storyboard)
@IBDesignable
class UXButton: UIButton {
    
    // @IBInspectable to make it can adjust in attribute inspector
    // Compute properties with default value 0
    @IBInspectable var cornerRadius: CGFloat = 10 {
        didSet {
            self.layer.cornerRadius = cornerRadius
        }
    }
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            self.layer.borderWidth = borderWidth
        }
    }
    @IBInspectable var borderColor: UIColor = UIColor.custom_lightGreen {
        didSet {
            self.layer.borderColor = borderColor.cgColor
        }
    }
    
}


class UTButton: UIButton {
    
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
    @IBInspectable var borderColor: UIColor = UIColor.custom_black {
        didSet {
            self.layer.borderColor = borderColor.cgColor
        }
    }
    
}
