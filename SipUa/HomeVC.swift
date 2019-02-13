//
//  HomeVC.swift
//  SipUa
//
//  Created by NLDeviOS on 11/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit

class HomeVC: UIViewController {
    @IBOutlet weak var midBar: UIView!
    @IBOutlet weak var btnCOntact: UIButton!
    
    @IBOutlet weak var btnPhoneP: UIButton!
    
    @IBOutlet weak var btnHistory: UIButton!
    @IBOutlet weak var btnMenu: UIBarButtonItem!
 
    
    @IBOutlet weak var contactView: UIView!
    
    @IBOutlet weak var historyView: UIView!
    
    @IBOutlet weak var phonePadView: UIView!
    
    
//    let slidHD = SooninSlideInHandler()
    var sidebarView: SidebarView!
    var blackScreen: UIView!
    var isPressContact = false
    var isPressHistory = false
    var isPressPhonePad = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpView()
        contactView.isHidden = false
        historyView.isHidden = true
        phonePadView.isHidden = true
    }
    
    @IBAction func menuBar(_ sender: Any) {
        
    }
    
    
    func setUpView(){
                midBar.layer.shadowOffset = CGSize(width: 0, height: 1.0)
                midBar.layer.shadowOpacity = 0.2
                midBar.layer.shadowRadius = 4.0
        
        self.title = "Home"
        let btnMenu = UIBarButtonItem(image: UIImage(named: "bic"), style: .plain, target: self, action: #selector(btnMenuAction))
        btnMenu.tintColor = #colorLiteral(red: 0, green: 0.9768045545, blue: 0, alpha: 1)
        self.navigationItem.leftBarButtonItem = btnMenu
        
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
        phonePadView.tintColor = #colorLiteral(red: 0, green: 0.9768045545, blue: 0, alpha: 1)
        
        
    }
    
    //TODO: - Contact
    @IBAction func pressContact(_ sender: Any) {
    isPressContact = !isPressContact
        if isPressContact{
        
       self.btnCOntact.layer.backgroundColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
       btnCOntact.tintColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
       btnCOntact.layer.cornerRadius = 20
            
        isPressContact = !isPressContact
            self.btnHistory.layer.borderColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            btnHistory.tintColor = #colorLiteral(red: 0.1215686275, green: 0.1294117647, blue: 0.1411764706, alpha: 1)
            btnHistory.layer.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            historyView.isHidden = true
            contactView.isHidden = false
            phonePadView.isHidden = true
        }
        
    }
    //TODO: - History
    @IBAction func pressHistory(_ sender: Any) {
    isPressHistory = !isPressHistory
        if isPressHistory{
            self.btnHistory.layer.backgroundColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            btnHistory.tintColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            btnHistory.layer.cornerRadius = 20
            self.btnCOntact.layer.borderColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            btnCOntact.tintColor = #colorLiteral(red: 0.1215686275, green: 0.1294117647, blue: 0.1411764706, alpha: 1)
            btnCOntact.layer.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            isPressHistory = !isPressHistory
            historyView.isHidden = false
            contactView.isHidden = true
            phonePadView.isHidden = true
        }
        
    }
    
    @IBAction func pressPhone(_ sender: Any ) {
        isPressPhonePad = !isPressPhonePad
          if isPressPhonePad  {
            phonePadView.isHidden = false
            contactView.isHidden = true
            historyView.isHidden = true
            
        }
        
    }
    
    
    
    
    
    //Slide Menu
    @objc func btnMenuAction(){
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
    
}

extension HomeVC : SidebarViewDelegate {
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
        case .calling_Setting:
            print("l")
        case .about:
            print("about")
        case.general_Setting:
            print("general setting")
        case .home:
            print("home")
        case .logout:
            print("Sign out")
        case .none:
            break
        }
    }
}
