//
//  AppDelegate.swift
//  SipUa
//
//  Created by NLDeviOS on 7/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import SipUAFramwork
import LinphoneModule
import PushKit
import UserNotifications
import AudioToolbox

//MARK: - Global properties
/** SipUAManager Global properties */
let sipUAManager: SipUAManager = AppDelegate.shared.sipUAManager
///** CallKit Provider Global properties */
let Provider: CallKitProvider = AppDelegate.shared.callKitProvider
///** CallKit Controller Global properties */
let Controller: CallKitCallController = AppDelegate.shared.callKitCallController

public enum AppStoryboard: String {
    // All storyboard in app
    case Main, Calling, History
    private var instance: UIStoryboard {
        return UIStoryboard(name: self.rawValue, bundle: nil)
    }
    // Contraint a generic type with UIViewController means requiring T to be a subclass of UIViewController
    func viewController<T: UIViewController>(viewControllerClass: T.Type) -> T {
        let storyboardID = (viewControllerClass as UIViewController.Type).storyboardID
        return self.instance.instantiateViewController(withIdentifier: storyboardID) as! T
    }
}

/** Structure string for application view controller class name */
public struct AppViewController {
    struct Name {
        static let StartingView = "StartingView"
        static let RegisterView = "RegisterView"
        static let MainView = "MainHomeVC"
        static let CallingView = "CallingView"
        static let HistoryView = "HistoryVC"
    }
}

public struct UserNotification {
    // Using for setting action when creating category
    // Using for checking action from user when user tap button in notification
    struct Action {
        // Calling
        static let AnswerAudio = "Answer Audio"
        static let AnswerVideo = "Answer Video"
        static let Decline = "Decline"
        // Messaging
        static let Reply = "Reply"
        static let MarkAsRead = "MarkAsRead"
        // Video call request
        static let Accept = "Accept"
        static let Cancel = "Cancel"
        // Open camera request
        static let Open = "Open"
        static let Close = "Close"
    }
    // Using for creating a category link with action and add to notification center
    // Using for setting category for local notification to show button in notification
    // No missed call category because missed call doesn't need any button
    struct Category {
        static let AudioCall = "Audio Call"
        static let VideoCall = "Video Call"
        static let Message = "Message"
        static let RequestVideoCall = "Request Video Call"
        static let RequestOpenCamera = "Request Open Camera"
    }
    // Using for request local notification to show to user
    // Using for remove local notification from notification center
    struct Identifier {
        static let IncomingCall = "Incoming Call"
        static let MissedCall = "Missed Call"
        static let MessageReceived = "Message Received"
        static let RequestVideoCall = "Request Video Call"
        static let RequestOpenCamera = "Request Open Camera"
    }
}

// MARK: - Structure string for voip push
public struct VoIPPush {
    // Using for checking type of push
    struct Types {
        static let Call = "Call"
        static let Message = "Message"
    }
}

//MARK: - Appdelegate class
@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    class var shared: AppDelegate{
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    let callKitProvider = CallKitProvider()
    let callKitCallController = CallKitCallController()
    let sipUAManager = SipUAManager.instance()
    // Property to check app received push wake or not
    // If received, That means register session for user at brekeke server is expire
    var receivedPushWake: Bool = false
   
    // A call id for incoming call/incoming message push notification, To check whether call id is already precess with CallKit or not
    private var pushCallIDs: [String:String] = [:]
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Initialize library
        sipUAManager.initSipUAManager()
        // Enable using CallKit
        sipUAManager.enableCallKit(enable: true)
        
        var appState: String = "No State"
        switch application.applicationState {
        case .active:
            appState = "Active"
        case .inactive:
            appState = "Inactive"
        case .background:
            appState = "Background"
        }
        
        os_log("AppDelegate : App launched with state : %@", log: log_app_debug, type: .debug, appState)
        os_log("AppDelegate : Launching with option : %@", log: log_app_debug, type: .debug, launchOptions?.description ?? "No options")
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        os_log("AppDelegate : applicationDidEnterBackground", log: log_app_debug, type: .debug)
        
        // Enter background mode
        sipUAManager.enterBackgroundMode()
        
        // Update app badge number
        updateApplicationBadgeNumber()
        
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
         os_log("AppDelegate : applicationWillEnterForeground", log: log_app_debug, type: .debug)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        os_log("AppDelegate : applicationWillTerminate", log: log_app_debug, type: .debug)
        // Terminate all calls
        sipUAManager.terminateAllCalls()
        
        // Destroy linphone is automatic unregister proxy, But if we are using push notification we want to continue receiving them
        // Set network reachable to false to avoid sending unregister
        if sipUAManager.getPushNotificationToken() != nil && sipUAManager.isEnabledPushNotification() {
            os_log("AppDelegate : Set network reachable to avoid sending unregister", log: log_app_debug, type: .debug)
            sipUAManager.setNetworkReachable(reachable: false)
        }
        
        // Destroy linphone core
        sipUAManager.destroyLinphoneCore()
    }
    
    /* Present incoming call view */
    public func presentIncomingCallView(call: OpaquePointer, animated: Bool) {
        os_log("AppDelegate : Present calling view container with incoming subview", log: log_app_debug, type: .debug)
        // Get CallingView instance
        if let callingView = CallingView.viewControllerInstance() {
            // Define a view and class to show
            
            callingView.xibName = AppView.XibName.IncomingCall
            callingView.toClass = AppView.ClassName.IncomingCall
            
            // Set video call status
//            callingView.isVideoCall = sipUAManager.isRemoteVideoEnabled(call: call)
            
            // Set caller status
            callingView.isCaller = false
            os_log("AppDelegate : isCaller : %@", log: log_app_debug, type: .debug, callingView.isCaller ? "true" : "false")
            // Check overlap incoming call
            if sipUAManager.countIncomingCall() > 1 {
                os_log("AppDelegate : Found overlap incoming call", log: log_app_debug, type: .debug)
                callingView.isAnotherCallComing = true
            } else {
                os_log("AppDelegate : Not found overlap incoming call", log: log_app_debug, type: .debug)
                callingView.isAnotherCallComing = false
            }

            // Check view controller
            if let window = self.window, let rootViewController = window.rootViewController {
                var currentController = rootViewController
                // Get the latest view controller that present from the previous view controller not just from root view controller
                while let presentedController = currentController.presentedViewController {
                    currentController = presentedController
                }
                os_log("AppDelegate : Current view controller : %@", log: log_app_debug, type: .debug, currentController.title ?? "nil")
                if currentController.title == AppViewController.Name.CallingView {
                    os_log("AppDelegate : CallingView is already presented, Load incoming call subview", log: log_app_debug, type: .debug)
                    (currentController as! CallingView).refreshLoadContentView()
                } else {
                    os_log("AppDelegate : Present callingView with incoming call subview", log: log_app_debug, type: .debug)
                    currentController.present(callingView, animated: animated, completion: nil)
                }
            }
        }
    }
    
    /* Show local notification message received */
    public func showMessageReceivedLocalNotification(message: OpaquePointer) {
        // Create a new local notification to show
        let content = UNMutableNotificationContent()
        let remoteAddr = sipUAManager.getMessageRemoteAddress(message: message)
        content.title = "Message from \((SipUtils.getDisplayNameFromAddress(address: remoteAddr) ?? SipUtils.getUsernameFromAddress(address: remoteAddr)) ?? "[Unknown]")."
        content.body = sipUAManager.getMessageText(message: message)
        content.categoryIdentifier = UserNotification.Category.Message
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "ringchat.wav"))
        let username = SipUtils.getUsernameFromAddress(address: remoteAddr)!
        let callID = sipUAManager.getMessageCallID(message: message)
        let dictionary: [AnyHashable:Any] = ["call-id" : callID]
        content.userInfo = dictionary
        // Using indentifier plus username because we want to show the same local notification if username is the same
        let request = UNNotificationRequest(identifier: UserNotification.Identifier.MessageReceived + username, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error: Error?) in
            if error != nil {
                os_log("AppDelegate : Add local notification error", log: log_app_error, type: .error)
            }
        })
    }
    
    // MARK: - Others
    /* Count all unread message and missed call for application icon badge number */
    public func updateApplicationBadgeNumber() {
        var count = 0
        count += sipUAManager.getAllMissedCallCount()
        os_log("AppDelegate : Update application badge number : %i", log: log_app_debug, type: .debug, count)
        UIApplication.shared.applicationIconBadgeNumber = count
    }
    
    /* Vibrate a phone manually */
    public func vibratePhone() {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    // MARK: - Notification
    /* Show notification ui */
    func processPush(userInfo: Dictionary<AnyHashable, Any>, identifier: String) {
        os_log("AppDelegate : Process push : %@", log: log_app_debug, type: .debug, userInfo.description)
        
        // Get the data in notification
        // Check aps key
        let payloadDict = userInfo["aps"] as? [String : AnyObject]
        // Check payload data
        if payloadDict == nil {
            os_log("AppDelegate : aps is empty, Unable to process notification", log: log_app_error, type: .error)
            return
        }
        // Check aps2 key
        let customDict = userInfo["aps2"] as? [String : AnyObject]
        // Check custom payload data
        if customDict == nil {
            os_log("AppDelegate : aps2 is empty, Push is from test push ", log: log_app_error, type: .error)
            // Show local notification
            let content = UNMutableNotificationContent()
            content.title = "APNS Pusher Test. APS2 is nil."
            content.body = "Push notification received."
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error: Error?) in
                if error != nil {
                    os_log("AppDelegate : Add local notification error", log: log_app_error, type: .error)
                }
            })
            return
        }
        
        // Check push user
        let pushUser = customDict!["push-user"] as? String
        if pushUser == nil {
            os_log("AppDelegate : Push user is nil", log: log_app_error, type: .error)
            return
        } else {
            os_log("AppDelegate : Push user is : %@", log: log_app_debug, type: .debug, pushUser!)
            // Check is class created
            if sipUAManager.isInstanciated() {
                // Get default config username to check push user is for this device
                if let defaultConfig = sipUAManager.getDefaultConfig(), sipUAManager.isEnabledPushNotification() {
                    let configUsername = SipUtils.getIdentityUsernameFromConfig(config: defaultConfig)
                    if configUsername == pushUser {
                        os_log("AppDelegate : Push is belong to this device", log: log_app_debug, type: .debug)
                        sipUAManager.refreshRegister()
                    } else {
                        os_log("AppDelegate : Push is for : %@, Ignor it", log: log_app_debug, type: .debug)
                        return
                    }
                } else {
                    os_log("AppDelegate : No default config or default config is not eanble push, Can't process push", log: log_app_error, type: .error)
                    return
                }
            } else {
                os_log("AppDelegate : SipUAManager isn't initialize yet, Can't process push", log: log_app_error, type: .error)
                return
            }
        }
        
        // Save call to push dict to use in library and start background task to show notification missed call or received message
        let callID = customDict!["call-id"] as? String ?? ""
        let category = payloadDict!["category"] as? String ?? ""
        let wakePush = customDict!["wake-push"] as? String ?? ""
        os_log("AppDelegate : Call id : %@", log: log_app_debug, type: .debug, callID)
        os_log("AppDelegate : Category : %@", log: log_app_debug, type: .debug, category)
        os_log("AppDelegate : Wake push : %@", log: log_app_debug, type: .debug, wakePush)
        
        if wakePush == "YES" {
            // Set push wake to indicate that register session at brekeke server is expire
            receivedPushWake = true
//            guard appStartBgTask == .invalid else { return }
            // Start background task to wait library and app run in terminate state
//            appStartBgTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
//                os_log("AppDelegate : Background task for launching application expired", log: log_app_debug, type: .debug)
//                UIApplication.shared.endBackgroundTask(self.appStartBgTask)
//                self.appStartBgTask = .invalid
//            })
            // Perform some task to gain a time from background task
            // Refresh network once
            sipUAManager.refreshNetworkReachability()
            // Check network reachability
            if !sipUAManager.isNetworkReachable() {
                os_log("AppDelegate : Network is down, Restart it", log: log_app_debug, type: .debug)
                sipUAManager.resetConnectivity()
            }
            return
        }
        
        // If no call id, Push is from APNS testing
        if callID == "" || category == "" {
            // Show local notification
            let content = UNMutableNotificationContent()
            content.title = "APNS Pusher Test. Call id is empty."
            content.body = "Push notification received."
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error: Error?) in
                if error != nil {
                    os_log("AppDelegate : Add local notification error", log: log_app_error, type: .error)
                }
            })
        }
        
        // Check category
        if category == VoIPPush.Types.Call {
            // Call is already active
            // Case app is already running (active/inactive/background/...)
            // - INVITE(incoming call) comes first, show incoming call view, push cames later, do not add call id to push call id dictionary
            // Case app is not running
            // - Push comes, app is going to run(didFinishLaunchingWithOptions), SipUA library is already started and notifying incoming call,
            //   app is not add observer for SipUA notification yet, need to add call id to push call id dictionary
            if sipUAManager.getAllCalls().count != 0 {
                os_log("AppDelegate : Call is already handle", log: log_app_debug, type: .debug)
                // In case app received push wake from brekeke server to wait register after that the real push for incoming call comes
                // but that time a library will handle and start incoming call already so it reject to add call id to push call id
                // Preventing by checking received push wake property
                if UIApplication.shared.applicationState != .active && receivedPushWake {
                    os_log("AppDelegate : Add real call id from call to push call id dictionary", log: log_app_debug, type: .debug)
                    addPushCallID(callID: callID, category: category)
                    // Check received push
                    if let mainView = MainHomeVC.viewControllerInstance() {
                        mainView.checkReceivedPush()
                    }
                }
                // Always set push wake back to false
                receivedPushWake = false
                return
            }
        } else if category == VoIPPush.Types.Message {
            // Message is already received
            if sipUAManager.getMessageFromCallID(callID: callID) != nil {
                os_log("AppDelegate : Message is already handle", log: log_app_debug, type: .debug)
                return
            }
        } else {
            os_log("AppDelegate : Not support category", log: log_app_debug, type: .debug)
            return
        }
        
        // If add call id for long running background task success and app is not active
        if UIApplication.shared.applicationState != .active {
            if sipUAManager.addCallIDForLongTaskBG(category: category, callID: callID) {
                os_log("AppDelegate : Start push long running background task", log: log_app_debug, type: .debug)
                sipUAManager.startPushLongRunningTask(category: category, callID: callID)
            }
        } else {
            os_log("AppDelegate : Application is active, Can't add call id for long task background", log: log_app_debug, type: .debug)
        }
        
        if !sipUAManager.isNetworkReachable() {
            os_log("AppDelegate : Network is down, Restart it", log: log_app_debug, type: .debug)
            sipUAManager.resetConnectivity()
        }
        
        if UIApplication.shared.applicationState != .active {
            os_log("AppDelegate : Add call id to push call id dictionary", log: log_app_debug, type: .debug)
            addPushCallID(callID: callID, category: category)
        } else {
            os_log("AppDelegate : Application is active, Can't add call id to push call id dictionary", log: log_app_debug, type: .debug)
        }
        
    }
    
    /* Show local notification incoming call */
    public func showIncomingCallLocalNotification(call: OpaquePointer) {
        // Create a new local notification to show
        let content = UNMutableNotificationContent()
        let isVideoCall = sipUAManager.isRemoteVideoEnabled(call: call)
        content.title = "Incoming \(isVideoCall ? "video" : "audio") call."
        content.body = "From \((sipUAManager.getRemoteDisplayName(call: call) ?? sipUAManager.getRemoteUsername(call: call)) ?? "[Unknown]")"
        content.categoryIdentifier = isVideoCall ? UserNotification.Category.VideoCall : UserNotification.Category.AudioCall
        let username = sipUAManager.getRemoteUsername(call: call)!
        let callID = sipUAManager.getCallCallID(call: call)
        let dictionary: [AnyHashable:Any] = ["call-id" : callID]
        content.userInfo = dictionary
        // Using indentifier plus username because we want to remove specific notification from notification center later
        let request = UNNotificationRequest(identifier: UserNotification.Identifier.IncomingCall + username, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error: Error?) in
            if error != nil {
                os_log("AppDelegate : Add local notification error", log: log_app_error, type: .error)
            }
        })
    }
    
    /* Add call id from push to dictionary */
    public func addPushCallID(callID: String?, category: String?) {
        guard callID != nil && callID != "" && category != nil && category != "" else {
            os_log("AppDelegate : Call id is nil or empty | Category is nil or empty, Can't add to push call id dictionary", log: log_app_debug, type: .debug)
            return
        }
        // Check received push wake
        // If true, register session at brekeke server is expire
        if !receivedPushWake {
            os_log("AppDelegate : Not receiving push wake, Continue check call in library", log: log_app_debug, type: .debug)
            if category == VoIPPush.Types.Call {
                for call in sipUAManager.getAllCalls() where sipUAManager.getCallCallID(call: call) == callID! {
                    os_log("AppDelegate : Call id for call [%@] is already handle", log: log_app_debug, type: .debug, callID!)
                    return
                }
            } else if category == VoIPPush.Types.Message {
                if sipUAManager.getMessageFromCallID(callID: callID) != nil {
                    os_log("AppDelegate : Call id for message [%@] is already handle", log: log_app_debug, type: .debug, callID!)
                    return
                }
            }
        }
        os_log("AppDelegate : Receiving push wake, Continue add call id to push call id", log: log_app_debug, type: .debug)
        if !checkPushCallID(callID: callID) {
            os_log("AppDelegate : Add push call id : %@ | category : %@", log: log_app_debug, type: .debug, callID!, category!)
            pushCallIDs[callID!] = category
        }
        os_log("AppDelegate : Push call id dictionary : %@", log: log_app_debug, type: .debug, pushCallIDs)
    }
    
    
    
    /* Check push call id is already add or not */
    public func checkPushCallID(callID: String?) -> Bool {
        guard callID != nil && callID != "" else {
            os_log("AppDelegate : Call id is nil or empty, Can't check call id in push call id dictionary", log: log_app_debug, type: .debug)
            return false
        }
        for (key,value) in pushCallIDs where key == callID! {
            os_log("AppDelegate : Found push call id : %@ | category : %@", log: log_app_debug, type: .debug, key, value)
            return true
        }
        return false
    }
    
    /* Get push call id dictionary */
    public func getPushCallID() -> [String:String] {
        return pushCallIDs
    }
    
    /* Clear call id from push dictionary */
    public func clearPushCallID() {
        pushCallIDs = [:]
    }
    
    /* Remove push call id from dictionary */
    public func removePushCallID(callID: String?) {
        guard callID != nil && callID != "" else {
            os_log("AppDelegate : Call id is nil or empty, Can't remove from push call id dictionary", log: log_app_debug, type: .debug)
            return
        }
        for (key,value) in pushCallIDs where key == callID! {
            os_log("AppDelegate : Remove push call id : %@ | category : %@", log: log_app_debug, type: .debug, key, value)
            pushCallIDs[key] = nil
            break
        }
        os_log("AppDelegate : Push call id dictionary : %@", log: log_app_debug, type: .debug, pushCallIDs)
    }
    
    /* Show local notification missed call */
    public func showMissedCallLocalNotification(call: OpaquePointer) {
        let content = UNMutableNotificationContent()
        content.title = "Missed call."
        content.body = "From \((sipUAManager.getRemoteDisplayName(call: call) ?? sipUAManager.getRemoteUsername(call: call)) ?? "[Unknown]")"
        let username = sipUAManager.getRemoteUsername(call: call)!
        // Using indentifier plus username because we want to show the same local notification if username is the same
        let request = UNNotificationRequest(identifier: UserNotification.Identifier.MissedCall + username, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error: Error?) in
            if error != nil {
                os_log("AppDelegate : Add local notification error", log: log_app_error, type: .error)
            }
        })
    }
    
    
    


}

// MARK: - Extension delegate for VoIP push
extension AppDelegate: PKPushRegistryDelegate {
    /* Register VoIP notification success */
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        os_log("AppDelegate : didUpdate", log: log_app_debug, type: .debug)
        os_log("AppDelegate : VoIP token is update", log: log_app_debug, type: .debug)
        let tmpToken = pushCredentials.token.map({ (data) -> String in
            String(format: "%02.2hhx", data)
        }).joined()
        os_log("AppDelegate : VoIP token : %@", log: log_app_debug, type: .debug, tmpToken)
        sipUAManager.setPushNotificationToken(token: pushCredentials.token)
    }
    /* Register VoIP notification failed */
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        os_log("AppDelegate : didInvalidatePushTokenFor", log: log_app_debug, type: .debug)
        os_log("AppDelegate : VoIP token is invalid", log: log_app_debug, type: .debug)
        sipUAManager.setPushNotificationToken(token: nil)
    }
    /* VoIP notification received */
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        os_log("AppDelegate : Receive VoIP notification", log: log_app_debug, type: .debug)
        guard type == .voIP else {
            os_log("AppDelegate : Push type is not VoIP", log: log_app_debug, type: .debug)
            return
        }
        // Refresh network once
        sipUAManager.refreshNetworkReachability()
        // Send payload push to show notification
        processPush(userInfo: payload.dictionaryPayload, identifier: "VoIP")
        completion()
    }
    
}

