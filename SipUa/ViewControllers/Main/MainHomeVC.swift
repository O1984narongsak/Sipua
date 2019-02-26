//
//  MainHomeVC.swift
//  SipUa
//
//  Created by NLDeviOS on 13/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import JAPagerViewController
import SipUAFramwork
import LinphoneModule
import AVFoundation
import CallKit
import CoreTelephony
import UserNotifications

/** Structure string for application subview class name and xib name */
public struct AppView {
    
    struct ClassName {
        static let IncomingCall = "IncomingCall"
        static let OutgoingCall = "OutgoingCall"
        static let ConferenceCall = "ConferenceCall"
    }
    
    struct XibName {
        
        static let IncomingCall = "IncomingCallView"
        static let OutgoingCall = "OutgoingCallView"
        static let ConferenceCall = "ConferenceCallView"
    }
    
}

public struct AppViewCell {
    struct Identifier {
        static let UserCell = "UserCell"
        static let PauseCallCell = "PauseCallCell"
        static let SelectPauseCallCell = "SelectPauseCallCell"
        static let ConferenceCallCell = "ConferenceCallCell"
        static let ConferencePauseCallCell = "ConferencePauseCallCell"
    }
}

/** Enumuration for loading view result */
public enum LoadViewResult: String {
    case NotLoadTheSameView = "Don't load the same view"
    case LoadViewSuccess = "Load view success"
    case AccessibilityIdentifierNotSet = "Subview is not set accessibilityIdentifier in .xib"
}

/** To let CallKit handle audio session */
let useCallKit = Platform.isSimulator ? false : sipUAManager.isCallKitEnabled()

/** To let CallKit automatically resume pause call or not */
var autoResumeCall: Bool = false
/** To let re-active call with CallKit automatically if conference call*/
var isConference: Bool = false

class MainHomeVC: BaseVC {
    
    @IBOutlet weak var view_main: UIView!
    
    private static var mainViewInstance: MainHomeVC?
    

    

    
    static func viewControllerInstance() -> MainHomeVC? {
        if mainViewInstance == nil {
            // Add instance
            mainViewInstance = MainHomeVC.instantiateFromAppStoryboard(appStoryboard: .Main)
        }
        return mainViewInstance
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let prxCfg = sipUAManager.getDefaultConfig(){
            let username = SipUtils.getIdentityUsernameFromConfig(config: prxCfg)
            os_log("MainView : Default proxy configuration username : %@", log: log_app_debug, type: .debug, username ?? "")
        }
        
        // Debug to get all config by identity username
        var arrayConfigUsername: [String] = []
        for prxCfg in sipUAManager.getAllConfigs() {
            let eachCfgUsername = SipUtils.getIdentityUsernameFromConfig(config: prxCfg!)
            arrayConfigUsername.append(eachCfgUsername!)
        }
        os_log("MainView : All config username : %@", log: log_app_debug, type: .debug, arrayConfigUsername)
        
        // Debug to get all auth info by username
        var arrayAuthInfoUsername: [String] = []
        for authInfo in sipUAManager.getAllAuthInfos() {
            let eachAuthInfoUsername = SipUtils.getUsernameFromAuthInfo(authInfo: authInfo!)
            arrayAuthInfoUsername.append(eachAuthInfoUsername!)
        }
        os_log("MainView : All auth info username : %@", log: log_app_debug, type: .debug, arrayAuthInfoUsername)
    
        
        let page1 = UIStoryboard.init(name: "Contracts", bundle: Bundle.main).instantiateViewController(withIdentifier: "ContactID") as! ContactVC
        page1.title = "Contact"
        
        let page2 = UIStoryboard.init(name: "History", bundle: Bundle.main).instantiateViewController(withIdentifier: "HistoryID") as! HistoryVC
        page2.title = "History"
        
        let page3 = UIStoryboard.init(name: "PhonPad", bundle: Bundle.main).instantiateViewController(withIdentifier: "PhonPadID") as! PhonPadVC
        page3.title = "PhonPad"
        
        let pager = JAPagerViewController(pages: [page1,page2,page3])
        
        
        addChild(pager)
        self.view_main.addSubview(pager.view)
        pager.didMove(toParent: self)
        pager.tabMenuHeight = 44 //stardard % 4 == 0
        pager.tabEqualWidth = view_main.frame.width / 3
        pager.tabItemWidthType = .equal
        pager.selectedTabTitleColor = UIColor.red
        pager.selectedTabTitleFont = UIFont.boldSystemFont(ofSize: 12)
        
        setUpView()
        debug()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
            registerForSipUANotifications()
            askAudioPermission()
                
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
            deregisterForSipUANotifications()
        
    }
    
    func setUpView(){
        
        self.addTitle(text: "Home")
        self.addHamberBar()
        
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
    
    // MARK: - Received call id from push
    @objc func checkReceivedPush() {
        // Debug app state
        switch UIApplication.shared.applicationState {
        case .active:
            os_log("MainView : App is active state (app run on foreground)", log: log_app_debug, type: .debug)
        case .inactive:
            os_log("MainView : App is inactive state", log: log_app_debug, type: .debug)
        case .background:
            os_log("MainView : App is background state (app not run -> push comes | app run -> tap home btn -> incoming call)", log: log_app_debug, type: .debug)
        default:
            os_log("MainView : App is unknow state", log: log_app_debug, type: .debug)
        }
        // Guard count call to make sure there is some call in library
        guard AppDelegate.shared.getPushCallID().count != 0 else {
            os_log("MainView : Not found push call id to process", log: log_app_debug, type: .debug)
            return
        }
        // Guard app state
        guard UIApplication.shared.applicationState != .active else {
            os_log("MainView : App state should be not active, Clear push call id", log: log_app_debug, type: .debug)
            AppDelegate.shared.clearPushCallID()
            return
        }
        // Guard the third incoming call and decline it
        guard sipUAManager.countIncomingCall() < 3 else {
            os_log("MainView : Incoming overlap call is more than 2, Destroy a third call with reason busy", log: log_app_debug, type: .debug)
            var count = 0
            for call in sipUAManager.getAllCalls() where sipUAManager.getStateOfCall(call: call) == LinphoneCallStateIncomingReceived {
                count += 1
                if count == 3 {
                    // Get call id
                    let callID = sipUAManager.getCallCallID(call: call)
                    os_log("MainView : Destroy call : %@", log: log_app_debug, type: .debug, sipUAManager.getRemoteUsername(call: call) ?? "Unknown")
                    // Destroy call as busy
                    sipUAManager.destroyAsBusyCall(call: call!)
                    // Show local notification missed call
                    AppDelegate.shared.showMissedCallLocalNotification(call: call!)
                    // Remove push call id if found
                    AppDelegate.shared.removePushCallID(callID: callID)
                    break
                }
            }
            return
        }
        // Get first push call id to process
        if let pushCallID = AppDelegate.shared.getPushCallID().first {
            // Get call id from first push call id
            let callID = pushCallID.key
            // Check category from first push call id
            if pushCallID.value == VoIPPush.Types.Call {
                // Check call from call id is exist or not
                if let call = sipUAManager.getCallFromCallID(callID: callID) {
                    // Guard call state is incoming received
                    guard sipUAManager.getStateOfCall(call: call) == LinphoneCallStateIncomingReceived else {
                        os_log("MainView : Call from first push call id is not in state incoming received", log: log_app_debug, type: .debug)
                        return
                    }
                    if useCallKit {
                        // CallKit
                        let uuid = UUID()
                        Provider.receiveCall(call: call, uuid: uuid) { (error: Error?) in
                            guard error == nil else { return }
                            // Present incoming call view
                            self.presentIncomingCallView(call: call, animated: false)
                        }
                    } else {
                        // Present incoming call view
                        presentIncomingCallView(call: call, animated: true)
                        // Start vibration the phone
                        sipUAManager.startVibration(sleepTime: 1.0)
                    }
                } else {
                    os_log("MainView : Call from first push call id doesn't exist", log: log_app_error, type: .error)
                }
                // Remove push call id if found
                AppDelegate.shared.removePushCallID(callID: callID)
            } else {
                // Check message from call id is exist or not
                if let message = sipUAManager.getMessageFromCallID(callID: callID) {
                    // Show local notification message received
                    AppDelegate.shared.showMessageReceivedLocalNotification(message: message)
                } else {
                    os_log("MainView : Message from push call id doesn't exist", log: log_app_error, type: .error)
                }
                // Remove push call id if found
                AppDelegate.shared.removePushCallID(callID: callID)
                
                os_log("MainView : First push call id is message, Try to find a push call id that is call", log: log_app_error, type: .error)
                // If push call id still left
                if AppDelegate.shared.getPushCallID().count != 0 {
                    // Check left push call id category for call
                    for (callID,category) in AppDelegate.shared.getPushCallID() where category == VoIPPush.Types.Call {
                        // Check call from call id is exist or not
                        if let call = sipUAManager.getCallFromCallID(callID: callID) {
                            // Guard call state is incoming received
                            guard sipUAManager.getStateOfCall(call: call) == LinphoneCallStateIncomingReceived else {
                                os_log("MainView : Call from left push call id is not in state incoming received", log: log_app_debug, type: .debug)
                                return
                            }
                            if useCallKit {
                                // CallKit
                                let uuid = UUID()
                                Provider.receiveCall(call: call, uuid: uuid) { (error: Error?) in
                                    guard error == nil else { return }
                                    // Present incoming call view
                                    self.presentIncomingCallView(call: call, animated: false)
                                }
                            } else {
                                // Present incoming call view
                                presentIncomingCallView(call: call, animated: true)
                                // Start vibration the phone
                                sipUAManager.startVibration(sleepTime: 1.0)
                            }
                        } else {
                            os_log("MainView : Call from left push call id doesn't exist", log: log_app_error, type: .error)
                        }
                        // Remove push call id if found
                        AppDelegate.shared.removePushCallID(callID: callID)
                        break
                    }
                } else {
                    os_log("MainView : No push call id left", log: log_app_debug, type: .debug)
                }
                
            }
        }
        
    }
    
    // MARK: - Present call view
    /* Present incoming call view */
    func presentIncomingCallView(call: OpaquePointer, animated: Bool) {
        os_log("MainView : Present calling view container with incoming subview", log: log_app_debug, type: .debug)
        // Get CallingView instance
        if let callingView = CallingView.viewControllerInstance() {
            // Define a view and class to show
            callingView.xibName = AppView.XibName.IncomingCall
            callingView.toClass = AppView.ClassName.IncomingCall
            // Set video call status
//            callingView.isVideoCall = sipUAManager.isRemoteVideoEnabled(call: call)
            // Set caller status
            callingView.isCaller = false
            os_log("MainView : isCaller : %@", log: log_app_debug, type: .debug, callingView.isCaller ? "true" : "false")
            // Check overlap incoming call
            if sipUAManager.countIncomingCall() > 1 {
                os_log("MainView : Found overlap incoming call", log: log_app_debug, type: .debug)
                callingView.isAnotherCallComing = true
            } else {
                os_log("MainView : Not found overlap incoming call", log: log_app_debug, type: .debug)
                callingView.isAnotherCallComing = false
            }
            // Set animation delegate
//            callingView.transitioningDelegate = self
            // Show CallingView
            present(callingView, animated: animated, completion: {
                
                // Check remain push call id to show local notification
                if AppDelegate.shared.getPushCallID().count != 0 {
                    os_log("MainView : Push call id remain", log: log_app_debug, type: .debug)
                    for pushCallID in AppDelegate.shared.getPushCallID() {
                        // Get call id from remain push call id
                        let callID = pushCallID.key
                        // Check category from remain push call id
                        if pushCallID.value == VoIPPush.Types.Call {
                            // Check call from call id is exist or not
                            if let call = sipUAManager.getCallFromCallID(callID: callID),
                                sipUAManager.getStateOfCall(call: call) == LinphoneCallStateIncomingReceived {
                                // Show local notification incoming call
                                AppDelegate.shared.showIncomingCallLocalNotification(call: call)
                            }
                        } else {
                            // Check push call id with message
                            if let message = sipUAManager.getMessageFromCallID(callID: callID) {
                                // Show local notification message received
                                AppDelegate.shared.showMessageReceivedLocalNotification(message: message)
                            }
                        }
                        // Remove push call id if found
                        AppDelegate.shared.removePushCallID(callID: callID)
                    }
                } else {
                    os_log("MainView : Push call id is empty", log: log_app_debug, type: .debug)
                    // Check another incoming call from library to show local notification
                    if sipUAManager.getCallsNumber() > 1 {
                        // Not a call active with CallKit
                        for call in sipUAManager.getAllCalls() where Controller.getUUID(call: call!) == nil {
                            // Show local notification incoming call
                            AppDelegate.shared.showIncomingCallLocalNotification(call: call!)
                        }
                    }
                }
                // After show calling view. Close this view
                os_log("MainView : Remove main view controller", log: log_app_debug, type: .debug)
                // Remove view from superview
                self.view.removeFromSuperview()
                // Check push call id again to make sure it's empty
                if AppDelegate.shared.getPushCallID().count != 0 {
                    os_log("MainView : Remain push call id, Need to handle it", log: log_app_debug, type: .debug)
                }
            })
        }
    }
    
    //MARK: - SipUa notifications
    /*  Add SipUa noti!  */
    func registerForSipUANotifications() {
        // Add notification to get call state change from library
        NotificationCenter.default.addObserver(self, selector: #selector(callStateUpdate), name: .kLinphoneCallStateUpdate, object: nil)
        
    }
    
    func deregisterForSipUANotifications() {
        NotificationCenter.default.removeObserver(self, name: .kLinphoneCallStateUpdate, object: nil)
        
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
            
            if let callingView = CallingView.viewControllerInstance() {
                //                // Stop update call duration timer in case call crash
                callingView.stopCallDurationTimer()
            }
            
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
        //yeah
    }
    
    // MARK: - Permissions
    /* Ask audio permission */
    func askAudioPermission() {
        let audioPermissionStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.audio)
        if audioPermissionStatus == AVAuthorizationStatus.authorized {
            os_log("MainView : Audio permission is already granted", log: log_app_debug, type: .debug)
//            askVideoPermission()
        } else if audioPermissionStatus == AVAuthorizationStatus.notDetermined {
            AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (granted: Bool) in
                if !granted {
                    let noticeAlert = UIAlertController(title: "Notice",
                                                        message: "Audio permission is not granted.\nThe audio call might not work.",
                                                        preferredStyle: UIAlertController.Style.alert)
                    noticeAlert.addAction(UIAlertAction(title: "Allow in settings", style: UIAlertAction.Style.default, handler: { (action) in
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                    }))
                    noticeAlert.addAction(UIAlertAction(title: "Close", style: UIAlertAction.Style.cancel, handler: { (action) in
//                        self.askVideoPermission()
                    }))
                    self.present(noticeAlert, animated: true, completion: nil)
                } else {
//                    self.askVideoPermission()
                }
            })
        } else {
            let noticeAlert = UIAlertController(title: "Notice",
                                                message: "Audio permission is not granted.\nThe audio call might not work.",
                                                preferredStyle: UIAlertController.Style.alert)
            noticeAlert.addAction(UIAlertAction(title: "Allow in settings", style: UIAlertAction.Style.default, handler: { (action) in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
            }))
            noticeAlert.addAction(UIAlertAction(title: "Close", style: UIAlertAction.Style.cancel, handler: { (action) in
//                self.askVideoPermission()
            }))
            self.present(noticeAlert, animated: true, completion: nil)
        }
    }
    

    
    
}
