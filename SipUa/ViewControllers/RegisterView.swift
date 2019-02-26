//
//  ViewController.swift
//  SipUa
//
//  Created by NLDeviOS on 7/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import DropDown
import SipUAFramwork
import LinphoneModule
import CoreTelephony

class RegisterView: UIViewController, UITextFieldDelegate  {
    
    @IBOutlet weak var passTxt: UITextField!
    @IBOutlet weak var usernameTxt: UITextField!
    @IBOutlet weak var oRemember: UIButton!
    @IBOutlet weak var oULPN: UIView!
    @IBOutlet weak var oULPass: UIView!
    @IBOutlet weak var oShowPass: UIButton!
    @IBOutlet weak var lbPN: UILabel!
    @IBOutlet weak var lbPW: UILabel!
    //TODO: - Regiter
    @IBOutlet weak var btnToHome: UIButton!
    @IBOutlet weak var btnBGToHome: UIView!
    
    //TODO: - DropDown
    @IBOutlet weak var tbList: UITableView!
    @IBOutlet weak var tbLHC: NSLayoutConstraint!
    @IBOutlet weak var btnDropDownList: UIButton!
    
    var isShowChecked = false
    var isSaveChecked = false
    var isPressPS = false
    var isPressPN = false
    
    var isShowList = false
    
    var positionPN: CGPoint!
    var positionPW: CGPoint!
    var listArr = [String]()
    
    var displayName: String?
    var username: String?
    var userId: String?
    var password: String?
    var domain: String?
    var port: Int?
    var destination: String?
    var transport: String?
    
    let dropDown = DropDown()
    
    /** To let CallKit handle audio session */
    let useCallKit = Platform.isSimulator ? false : sipUAManager.isCallKitEnabled()
    
    private static var registerViewInstance: RegisterView?
    //User
    var tmpSelectUser: OpaquePointer?
    
    static func viewControllerInstance() -> RegisterView? {
        if registerViewInstance == nil {
            // Add instance
            registerViewInstance = RegisterView.instantiateFromAppStoryboard(appStoryboard: .Main)
        }
        return registerViewInstance
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        debug()
        
    }
    
    func setupView() {
        
        positionPN = lbPN.center
        positionPW = lbPW.center
        lbPN.center = usernameTxt.center
        lbPW.center = passTxt.center
        oRemember.layer.cornerRadius = oRemember.frame.width/2
        oRemember.layer.borderWidth = 2
        oRemember.layer.borderColor = UIColor.custom_lightGreen.cgColor
        
        oShowPass.layer.cornerRadius = oShowPass.frame.height / 2
        oShowPass.layer.borderWidth = 2
        oShowPass.layer.borderColor = UIColor.custom_lightGreen.cgColor
        
        passTxt.addTarget(self, action: #selector(pressPass), for: UIControl.Event.touchDown)
        usernameTxt.addTarget(self, action: #selector(pressPN), for: UIControl.Event.touchDown)
        
        btnToHome.translatesAutoresizingMaskIntoConstraints = false
        
        tbList.delegate = self
        tbList.dataSource = self
        tbLHC.constant = 0
        tbList.isHidden = true
        dropDown.anchorView = btnDropDownList
        
        listArr = ["sip.linphone.org","ucc.ais.co.th"]
        dropDown.dataSource = ["sip.linphone.org","ucc.ais.co.th"]
    }
    
    func debug(){
        // Debug to get all config by identity username
        var arrayConfigUsername: [String] = []
        for prxCfg in sipUAManager.getAllConfigs() {
            let eachCfgUsername = SipUtils.getIdentityUsernameFromConfig(config: prxCfg!)
            arrayConfigUsername.append(eachCfgUsername!)
        }
        os_log("RegisterView : All config username : %@", log: log_app_debug, type: .debug, arrayConfigUsername)
        // Debug to get all auth info by username
        var arrayAuthInfoUsername: [String] = []
        for authInfo in sipUAManager.getAllAuthInfos() {
            let eachAuthInfoUsername = SipUtils.getUsernameFromAuthInfo(authInfo: authInfo!)
            arrayAuthInfoUsername.append(eachAuthInfoUsername!)
        }
        os_log("RegisterView : All auth info username : %@", log: log_app_debug, type: .debug, arrayAuthInfoUsername)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update status bar
        //        setNeedsStatusBarAppearanceUpdate()
        
        //hide keyboard when tap outside
        hideKeyboardWhenTappedAround()
        
        usernameTxt.delegate = self
        passTxt.delegate = self
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        os_log("RegisterView : viewWillDisappear()")
        
        os_log("RegisterView : Remove observer for keyboard", log: log_app_debug, type: .debug)
        deregisterFromKeyboardNotifications()
        
        os_log("RegisterView : Remove observer for call", log: log_app_debug, type: .debug)
        deregisterForSipUANotifications()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        os_log("RegisterView : viewDidAppear()")
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        os_log("RegisterView : viewDidDisappear()")
        
        // Clear instance to prevent load active view controller error
        RegisterView.registerViewInstance = nil
        
    }
    
    @objc func pressPass(textField: UITextField){
        isPressPS = !isPressPS
        
        if isPressPS{
            self.oULPass.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
            self.oULPN.layer.backgroundColor = UIColor.custom_black.cgColor
            lbPN.textColor = UIColor.custom_black
            lbPW.textColor = UIColor.custom_lightGreen
            if passTxt.text == "" && usernameTxt.text == "" {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.lbPW.center = self.positionPW
                    self.lbPW.font.withSize(17.0)
                    self.lbPN.center = self.usernameTxt.center
                    self.lbPN.font.withSize(30.0)
                })
            } else if passTxt.text == "" {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.lbPW.center = self.positionPW
                    self.lbPW.font.withSize(17.0)
                })
            } else if usernameTxt.text == ""  {
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.lbPN.center = self.usernameTxt.center
                    self.lbPN.font.withSize(30.0)
                })
            }
            isPressPS = !isPressPS
        }
        
    }
    
    @objc func pressPN(textField: UITextField){
        isPressPN = !isPressPN
        
        if isPressPN{
            self.oULPass.layer.backgroundColor = UIColor.custom_black.cgColor
            self.oULPN.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
            lbPW.textColor = UIColor.custom_black
            lbPN.textColor = UIColor.custom_lightGreen
            if usernameTxt.text == ""  && passTxt.text == "" {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.lbPN.center = self.positionPN
                    self.lbPN.font.withSize(17.0)
                    self.lbPW.center = self.passTxt.center
                    self.lbPW.font.withSize(30.0)
                })
            } else if usernameTxt.text == ""  {
                UIView.animate(withDuration: 0.3, animations: {
                    self.lbPN.center = self.positionPN
                    self.lbPN.font.withSize(17.0)
                })
            } else if passTxt.text == "" {
                UIView.animate(withDuration: 0.3, animations: {
                    self.lbPW.center = self.passTxt.center
                    self.lbPW.font.withSize(30.0)
                })
            }
            isPressPN = !isPressPN
        }
        
    }
    
    @IBAction func pressShowBtn(_ sender: UIButton) {
        isShowChecked = !isShowChecked
        if isShowChecked {
            sender.setTitle("✓", for: .normal)
            sender.setTitleColor(.white, for: .normal)
            self.oShowPass.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
            passTxt.isSecureTextEntry = false
        } else {
            sender.setTitle("", for: .normal)
            sender.setTitleColor(.red, for: .normal)
            self.oShowPass.layer.backgroundColor = UIColor.custom_white.cgColor
            passTxt.isSecureTextEntry = true
        }
        
        
    }
    
    @IBAction func pressSavePassBtn(_ sender: UIButton) {
        isSaveChecked = !isSaveChecked
        if isSaveChecked{
            sender.setTitle("✓", for: .normal)
            sender.setTitleColor(.white, for: .normal)
            self.oRemember.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
        } else {
            sender.setTitle("", for: .normal)
            sender.setTitleColor(.red, for: .normal)
            self.oRemember.layer.backgroundColor = UIColor.custom_white.cgColor
        }
        
    }
    //TODO: - DRopDown choose Domain
    
    @IBAction func selectNumberOfList(_ sender: Any) {
        dropDown.show()
        dropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            print("Selected item: \(item) at index: \(index)")
            self.btnDropDownList.titleLabel?.text = item
            self.domain = item
            print("domain \(String(describing: self.domain))")
        }
        
    }
    
    
    
    //TODO: - Login
    @IBAction func pressToHome(_ sender: UIButton) {
        
        if checkNeedValue(){
            setPushAnimation()
            register()
            registerSipUA()
            if sipUAManager.getRegisterStatus() == "Registered" {
                print(sipUAManager.getRegisterStatus())
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "MainNav")
                self.present(vc, animated: true, completion: nil)
            }
            
            
        }
        
        
        
    }
    
    func setPushAnimation(){
        
        UIView.animate(withDuration: 0.3, animations: {
            self.btnToHome.alpha = 0
            self.btnToHome.center = self.btnBGToHome.center
            self.btnBGToHome.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
        })
        
        
    }
    
    
    
    
    
}

//MARK: - UITableViewDelegate UITableViewDatasource
extension RegisterView : UITableViewDelegate,UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return listArr.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "numberofrooms")
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "numberofrooms")
            cell?.textLabel?.text = listArr[indexPath.row]
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        tbList.isHidden = true
    }
    
    /* Remove keyboard notification when show/hide */
    func deregisterFromKeyboardNotifications(){
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    /* Remove SipUA notification */
    func deregisterForSipUANotifications() {
        NotificationCenter.default.removeObserver(self, name: .kLinphoneCallStateUpdate, object: nil)
        NotificationCenter.default.removeObserver(self, name: .kLinphoneMessageReceived, object: nil)
    }
    
    // MARK: - Button action
    /* Press register button */
    @objc func register() {
        // Check nessescary value to register
        if checkNeedValue() {
            setUserPass()
            registerSipUA()
            ProgressHUD.show()
            print(sipUAManager.getRegisterStatus())
            chkregisterStatusss()
        }
    }
    
    func chkregisterStatusss(){
        //        1. Not registered
        //
        //        2. Registration in progress
        //
        //        3. Registered
        //
        //        4. Registration cleared
        //
        //        5. Registration failed
        //
        //        6. Not connected
        
        switch sipUAManager.getRegisterStatus() {
        case "Not registered":
            print("Not registered")
        case "Registration in progress":
            print("Registration in progress")
            self.chkregisterStatusss()
        case "Registered":
            print("Registered")
            ProgressHUD.dismiss()
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "MainHomeID") as! MainHomeVC
            // Set destination properties
            vc.usernameL = usernameTxt.text!
            vc.passL = passTxt.text!
//            mainView.currentUser
            navigationController?.pushViewController(vc, animated: true)
        case "Registration cleared":
            print("Registration cleared")
        case "Registration failed":
            print("Registration failed")
        case "Not connected":
            print("Not connected")
        default:
            break
        }
    }
    
    /* Check register value */
    func checkNeedValue() -> Bool {
        if usernameTxt.text == nil || usernameTxt.text == "" {
            
            presentAlert(withTitle: "Please insert a user name.", message: "")
            return false
            
        } else if passTxt.text == nil || passTxt.text == "" {
            presentAlert(withTitle: "Please insert a password.", message: "")
            return false
            
        } else if domain == nil || passTxt.text == "" {
            presentAlert(withTitle: "Please choose a domain .", message: "")
            return false
        }
        return true
    }
    
    func setUserPass(){
        username = usernameTxt.text
        password = passTxt.text
//        print("user: \(String(describing: username)) pass:\(String(describing: password)) ")
    }
    
    // MARK: - Registeration
    /* Register to linphone */
    func registerSipUA() {
        transport = "UDP"
        sipUAManager.register(displayName: displayName, userID: userId, username: username, password: password, domain: domain, port: port, destination: destination, transport: transport)
        // Set RTP encryption
//        if transport?.lowercased() == "tls" {
//            sipUAManager.enableRTPEncryptions(type: "srtp")
//        } else {
            sipUAManager.enableRTPEncryptions(type: nil)
//        }
    }
    
    
    
}
