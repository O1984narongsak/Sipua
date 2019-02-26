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

    @IBOutlet weak var oTFoPassword: UITextField!
    
    @IBOutlet weak var oTFoPhoneNumber: UITextField!
    
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

    }
    
    func setupView() {
        
        positionPN = lbPN.center
        positionPW = lbPW.center
        lbPN.center = oTFoPhoneNumber.center
        lbPW.center = oTFoPassword.center
        oRemember.layer.cornerRadius = oRemember.frame.width/2
        oRemember.layer.borderWidth = 2
        oRemember.layer.borderColor = UIColor.custom_lightGreen.cgColor
        
        oShowPass.layer.cornerRadius = oShowPass.frame.height / 2
        oShowPass.layer.borderWidth = 2
        oShowPass.layer.borderColor = UIColor.custom_lightGreen.cgColor
        
        oTFoPassword.addTarget(self, action: #selector(pressPass), for: UIControl.Event.touchDown)
        oTFoPhoneNumber.addTarget(self, action: #selector(pressPN), for: UIControl.Event.touchDown)
        
        btnToHome.translatesAutoresizingMaskIntoConstraints = false
        
        tbList.delegate = self
        tbList.dataSource = self
        tbLHC.constant = 0
        tbList.isHidden = true
        
        dropDown.anchorView = btnDropDownList
        
        listArr = ["sip.linphone.org","ucc.ais.co.th"]
        dropDown.dataSource = ["sip.linphone.org","ucc.ais.co.th"]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        viewWillAppear(animated)
        
        // Update status bar
        setNeedsStatusBarAppearanceUpdate()
        
        //hide keyboard when tap outside
        hideKeyboardWhenTappedAround()
        
        oTFoPhoneNumber.delegate = self
        oTFoPassword.delegate = self
        
        if sipUAManager.getDefaultConfig() != nil {
            registerForSipUANotifications()
        }
    }
    
    @objc func pressPass(textField: UITextField){
        isPressPS = !isPressPS
        
            if isPressPS{
                self.oULPass.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
                self.oULPN.layer.backgroundColor = UIColor.custom_black.cgColor
                lbPN.textColor = UIColor.custom_black
                lbPW.textColor = UIColor.custom_lightGreen
                if oTFoPassword.text == "" && oTFoPhoneNumber.text == "" {
                    
                    UIView.animate(withDuration: 0.3, animations: {
        
                        self.lbPW.center = self.positionPW
                        self.lbPW.font.withSize(17.0)
                        self.lbPN.center = self.oTFoPhoneNumber.center
                        self.lbPN.font.withSize(30.0)
                     })
                } else if oTFoPassword.text == "" {
                    
                    UIView.animate(withDuration: 0.3, animations: {
                        
                        self.lbPW.center = self.positionPW
                        self.lbPW.font.withSize(17.0)
                    })
                } else if oTFoPhoneNumber.text == ""  {
                    UIView.animate(withDuration: 0.3, animations: {
                        
                        self.lbPN.center = self.oTFoPhoneNumber.center
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
                if oTFoPhoneNumber.text == ""  && oTFoPassword.text == "" {
                
                    UIView.animate(withDuration: 0.3, animations: {
                      
                        self.lbPN.center = self.positionPN
                        self.lbPN.font.withSize(17.0)
                        self.lbPW.center = self.oTFoPassword.center
                        self.lbPW.font.withSize(30.0)
                    })
                } else if oTFoPhoneNumber.text == ""  {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.lbPN.center = self.positionPN
                        self.lbPN.font.withSize(17.0)
                        })
                } else if oTFoPassword.text == "" {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.lbPW.center = self.oTFoPassword.center
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
            oTFoPassword.isSecureTextEntry = false
        } else {
            sender.setTitle("", for: .normal)
            sender.setTitleColor(.red, for: .normal)
            self.oShowPass.layer.backgroundColor = UIColor.custom_white.cgColor
            oTFoPassword.isSecureTextEntry = true
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
    //TODO: - DRopDown
    
    @IBAction func selectNumberOfList(_ sender: Any) {
        dropDown.show()
        dropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            print("Selected item: \(item) at index: \(index)")
            self.btnDropDownList.titleLabel?.text = item
        }
//        isShowList = !isShowList
//        if isShowList{
//            tbList.isHidden = false
//            self.tbLHC.constant = 40 * 2
//            self.view.layoutIfNeeded()
//        }else{
//            tbList.isHidden = true
//        }
    }
    
    
    
    //TODO: - Login
    @IBAction func pressToHome(_ sender: UIButton) {
        setPushAnimation()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MainNav")
        self.present(vc, animated: true, completion: nil)
    }
    
    func setPushAnimation(){
        
        UIView.animate(withDuration: 0.3, animations: {
            self.btnToHome.alpha = 0
            self.btnToHome.center = self.btnBGToHome.center
            self.btnBGToHome.layer.backgroundColor = UIColor.custom_lightGreen.cgColor
            })
        
        
    }
    
    //MARK: - SipUa notifications
    /*  Add SipUa noti!  */
    func registerForSipUANotifications() {
        // Add notification to get call state change from library
        NotificationCenter.default.addObserver(self, selector: #selector(callStateUpdate), name: .kLinphoneCallStateUpdate, object: nil)
        // Add notification to get message received
        NotificationCenter.default.addObserver(self, selector: #selector(messageReceived), name: .kLinphoneMessageReceived, object: nil)
    }
    
    // MARK: - Calling
    /* Call state update from notification */
    @objc func callStateUpdate(notification: Notification) {
        
        // Cast dictionary value to call state
        let callState = notification.userInfo!["state"] as! LinphoneCallState
        // Convert to string
        let callStateString = SipUtils.callStateToString(callState: callState)
        os_log("RegisterView : Call state is %@", log: log_app_debug, type: .debug, callStateString)
        
        // Cast dictionary value to call
        let call = notification.userInfo!["call"] as! OpaquePointer
        
        // Cast dictionary value to call message
        let callMsg = notification.userInfo!["message"] as! String
        os_log("RegisterView : Call message is %@", log: log_app_debug, type: .debug, callMsg)
        
        // Handle all call state
        // MARK: Call Incoming received
        if callState == LinphoneCallStateIncomingReceived {
            
            // Get call name
            let callName = (sipUAManager.getRemoteDisplayName(call: call) ?? sipUAManager.getRemoteUsername(call: call)) ?? "Unknown"
            
            // Check gsm call
            guard Controller.getGSMCalls().count == 0 else {
                os_log("RegisterView : GSM call ongoing... rejecting call from [%@]", log: log_app_debug, type: .debug, callName)
                sipUAManager.destroyAsBusyCall(call: call)
                return
            }
            
            // Get username from remote address
            os_log("RegisterView : Incoming call from %@", log: log_app_debug, type: .debug, callName)
            
            if useCallKit {
                if sipUAManager.getCallsNumber() < 2 {
                    // CallKit
                    let uuid = UUID()
                    Provider.receiveCall(call: call, uuid: uuid) { (error: Error?) in
                        guard error == nil else { return }
                        // Present incoming call view
                        AppDelegate.shared.presentIncomingCallView(call: call, animated: false)
                    }
                }
            } else {
                // Present incoming call view
                AppDelegate.shared.presentIncomingCallView(call: call, animated: true)
                // Start vibration the phone
                sipUAManager.startVibration(sleepTime: 1.0)
            }
            
        }
            
            // MARK: Call Released
            // When make a call/receiving a call but hangup/decline call
        else if callState == LinphoneCallStateReleased {
            
//            if let callingView = CallingView.viewControllerInstance() {
//                // Stop update call duration timer in case call crash
//                callingView.stopCallDurationTimer()
//            }
            
            // Guard CallKit
            guard useCallKit else { return }
            
            // CallKit
            // When not answer yet but remote hangup
            if let uuid = Controller.getUUID(call: call) {
                os_log("RegisterView : End CallKit with remote end reason", log: log_app_debug, type: .debug)
                Provider.callProvider.reportCall(with: uuid, endedAt: nil, reason: .remoteEnded)
                // Remove call from controller manually, Because using call provider will not call function in CallKitProvider class
                //Controller.removeCall(call: call)
            } else {
                os_log("RegisterView : Can't get uuid from call to end", log: log_app_error, type: .error)
            }
            
        }
        
    }
    
    // MARK: - Messaging
    /* Message state update from notification */
    @objc func messageReceived(notification: Notification) {
        
        // Cast dictionary value to chat room
        let chatRoom = notification.userInfo!["chatRoom"] as! OpaquePointer
        
        // Cast dictionary value to remote address
        let remoteAddress = notification.userInfo!["remoteAddress"] as! String
        
        // Cast dictionary value to message
        let message = notification.userInfo!["message"] as! OpaquePointer
        
        // Cast dictionary value to text
        let text = notification.userInfo!["text"] as! String
        
        // Cast dictionary value to message call id
        let callID = notification.userInfo!["callID"] as! String
        
        // Summary all message details.
        let summary = String(format: "\nMessage received from : %@ (chat room pointer : %p )\nCall id : %@\nMessage text : %@ (message pointer : %p )", remoteAddress, chatRoom, callID, text, message)
        os_log("RegisterView : %@", log: log_app_debug, type: .debug, summary)
        
        os_log("RegisterView : Message received : Remote is composing : %@", log: log_app_debug, type: .debug, sipUAManager.isChatRoomRemoteComposing(chatRoom: chatRoom) ? "true" : "false")
        
        // Show local notification
        AppDelegate.shared.showMessageReceivedLocalNotification(message: message)
        
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
    
   
}
