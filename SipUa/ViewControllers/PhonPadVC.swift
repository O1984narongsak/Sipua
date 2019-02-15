//
//  PhonPadVC.swift
//  SipUa
//
//  Created by NLDeviOS on 14/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit

class PhonPadVC: UIViewController {
    
    @IBOutlet weak var phonpadView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUPViews()
    }
    
    func setUPViews() {
        self.phonpadView.layoutIfNeeded()
        let dialView: BMDialView = BMDialView()
        dialView.setupDialPad(frame: CGRect.init(x: 0,
                                                 y: 0,
                                                 width: self.phonpadView.frame.size.width,
                                                 height: self.phonpadView.frame.size.height))
        
        
        self.phonpadView.addSubview(dialView)
        dialView.callTapped = { number in
            print(number)
        }
    }
}
