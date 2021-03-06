//
//  BaseVC.swift
//  SipUa
//
//  Created by NLDeviOS on 14/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit

class BaseVC: UIViewController {

    //TODO: - slide menu
    var sidebarView: SidebarView!
    var blackScreen: UIView!

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    func addHamberBar() {
        self.navigationController?.isNavigationBarHidden = false
        
        let button: UIButton = UIButton(type: .custom)
        
        let imageView = UIImageView(image: UIImage(named: "bar"))
        
        button.setImage(imageView.image!, for: .normal)
        button.imageView?.image = button.imageView?.image?.withRenderingMode(.alwaysTemplate)
        button.imageView?.tintColor = UIColor.white
        button.contentHorizontalAlignment = .right
        button.addTarget(self, action: #selector(addHamberBarAction), for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 53, height: 31)
        
        let barButton = UIBarButtonItem(customView: button)
        
        navigationItem.leftBarButtonItem = barButton
        
        sidebarView = SidebarView(frame: CGRect(x: 0, y: 0, width: 0, height: self.view.frame.height))
        sidebarView.delegate = self
        sidebarView.layer.zPosition = 100
        self.view.isUserInteractionEnabled = true
        self.navigationController?.view.addSubview(sidebarView)
        
        blackScreen = UIView(frame: self.view.bounds)
        blackScreen.backgroundColor = UIColor(white: 0, alpha: 0.5)
        blackScreen.isHidden = true
        self.navigationController?.view.addSubview(blackScreen)
        blackScreen.layer.zPosition = 99

        let tapGestRecognizer = UITapGestureRecognizer(target:self, action: #selector(blackScreenTapAction(sender:)))
        blackScreen.addGestureRecognizer(tapGestRecognizer)

    }

    @objc func addHamberBarAction() {
        blackScreen.isHidden = false
        UIView.animate(withDuration: 0.3, animations: {
            self.sidebarView.frame = CGRect(x: 0, y: 0, width: 250, height: self.sidebarView.frame.height)
            
        }) {(complete) in
            self.blackScreen.frame = CGRect(x: self.sidebarView.frame.width, y: 0, width: self.view.frame.width - self.sidebarView.frame.width, height: self.view.bounds.height + 100 )}
    }
    
    @objc func blackScreenTapAction(sender: UITapGestureRecognizer){
        blackScreen.isHidden = true
        blackScreen.frame = self.view.bounds
        UIView.animate(withDuration: 0.3){
            self.sidebarView.frame = CGRect(x: 0, y: 0, width: 0, height: self.sidebarView.frame.height)
        }
    }
    
    // MARK: - addTitle
    func addTitle(text: String){
        let _label = UILabel(frame: CGRect(x: 0, y: 0, width: 60, height: 50))
        _label.text = text
        _label.textColor = UIColor.custom_black
        _label.numberOfLines = 2
        _label.textAlignment = .center
        //_label.minimumScaleFactor = 0.5
        _label.font = UIFont.boldSystemFontBold()
        _label.adjustsFontSizeToFitWidth = true
        self.navigationItem.titleView = _label
    }

}

//TODO: - Silde
extension BaseVC : SidebarViewDelegate {
    func sidebarDidSelectOldRow() {
        blackScreen.isHidden = true
        blackScreen.frame = self.view.bounds
        UIView.animate(withDuration: 0.3){
            self.sidebarView.frame = CGRect(x: 0, y: 0, width: 0, height: self.sidebarView.frame.height)
        }
    }
    
    func sidebarDidSelectRow(row: Row) {
        print("row: \(row)")
        blackScreen.isHidden = true
        blackScreen.frame = self.view.bounds
        UIView.animate(withDuration: 0.3){
            self.sidebarView.frame = CGRect(x: 0, y: 0, width: 0, height: self.sidebarView.frame.height)
        }
        switch row {
        case .editProfile:
            let vc = EditProfileVC()
            self.navigationController?.pushViewController(vc, animated: true)
            print("k")
        case .calling_Setting:
            presentAlert(withTitle: "Logout", message: "")
        case .about:
            presentAlert(withTitle: "Logout", message: "")
        case.general_Setting:
            presentAlert(withTitle: "Logout", message: "")
        case .home:
            presentAlert(withTitle: "Logout", message: "")
        case .logout:
            presentAlert(withTitle: "Logout", message: "")
        case .none:
            break
        }
    }
}
