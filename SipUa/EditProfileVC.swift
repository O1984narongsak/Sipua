//
//  EditProfileVC.swift
//  SipUa
//
//  Created by NLDeviOS on 12/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit

class EditProfileVC: BaseVC {
    
    let lbl : UILabel = {
        let label = UILabel()
        label.text = "Edit Profile"
        label.textColor = UIColor.custom_black
        label.font = UIFont.systemFontSmall()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpEditView()
    }
    
    func setUpEditView(){
        self.view.backgroundColor = UIColor.white
        self.view.addSubview(lbl)
        lbl.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        lbl.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        lbl.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 100).isActive = true
        lbl.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        self.addTitle(text: "Edit Profile")
        self.addHamberBar()
    }


}
