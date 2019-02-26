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

//MARK: - Appdelegate class
@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate {

    
    
    class var shared: AppDelegate{
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    var window: UIWindow?
    
    // Property for app background task
    var appStartBgTask: UIBackgroundTaskIdentifier = .invalid
    // Properties for CallKit and sipua
    let callKitProvider = CallKitProvider()
    let callKitCallController = CallKitCallController()
    let sipUAManager = SipUAManager.instance()
    // Property to check app received push wake or not
    // If received, That means register session for user at brekeke server is expire
    var receivedPushWake: Bool = false
    
    let transition = RightLeftTransition()
   
    // A call id for incoming call/incoming message push notification, To check whether call id is already precess with CallKit or not
    private var pushCallIDs: [String:String] = [:]
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        os_log("AppDelegate : didFinishLaunchingWithOptions", log: log_app_debug, type: .debug)
        
        // Start background task to init library
        appStartBgTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            os_log("AppDelegate : Background task for launching application expired", log: log_app_debug, type: .debug)
            UIApplication.shared.endBackgroundTask(self.appStartBgTask)
            self.appStartBgTask = .invalid
        })
        
        // Initialize library
        sipUAManager.initSipUAManager()
        // Enable using CallKit
        sipUAManager.enableCallKit(enable: true)
        
        // Stop launching background task
        if appStartBgTask != .invalid {
            UIApplication.shared.endBackgroundTask(appStartBgTask)
            appStartBgTask = .invalid
        }
        
        // Notifications
        registerNotifications()
        
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
//        content.categoryIdentifier = isVideoCall ? UserNotification.Category.VideoCall : UserNotification.Category.AudioCall
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
    
    // MARK: - VoIP push
    /* Register a VoIP notification */
    func registerNotifications() {
        os_log("AppDelegate : Register VoIP push", log: log_app_debug, type: .debug)
        // Get main queue
        let mainQueue = DispatchQueue.main
        // Create a push registry object
        let voipRegistry = PKPushRegistry(queue: mainQueue)
        // Set delegate
        voipRegistry.delegate = self
        // Set push type
        voipRegistry.desiredPushTypes = [.voIP]
        // Config action, category for notification
        configUINotification()
    }
    
    // MARK: - User notification
    /* Request permission and setup action, category */
    func configUINotification() {
        // Create set to collect notification category
        var notificationCategories: Set<UNNotificationCategory> = []
        
        // Calling
        // Audio only
        let actionAnswer = UNNotificationAction(identifier: UserNotification.Action.AnswerAudio, title: "Answer", options: [.foreground])
        let actionDecline = UNNotificationAction(identifier: UserNotification.Action.Decline, title: "Decline", options: [])
        let incomingAudioCallCategory = UNNotificationCategory(identifier: UserNotification.Category.AudioCall, actions: [actionAnswer,actionDecline], intentIdentifiers: [], options: [.customDismissAction])
        // Add to set
        notificationCategories.insert(incomingAudioCallCategory)
        // Video or audio
        let actionAnswerAudio = UNNotificationAction(identifier: UserNotification.Action.AnswerAudio, title: "Answer Audio", options: [.foreground])
        let actionAnswerVideo = UNNotificationAction(identifier: UserNotification.Action.AnswerVideo, title: "Answer Video", options: [.foreground])
        let actionDeclineCall = UNNotificationAction(identifier: UserNotification.Action.Decline, title: "Decline", options: [])
        let incomingVideoCallCategory = UNNotificationCategory(identifier: UserNotification.Category.VideoCall, actions: [actionAnswerAudio,actionAnswerVideo,actionDeclineCall], intentIdentifiers: [], options: [.customDismissAction])
        // Add to set
        notificationCategories.insert(incomingVideoCallCategory)
        
        // Request video call
        let actionAccept = UNNotificationAction(identifier: UserNotification.Action.Accept, title: "Accept", options: [.foreground])
        let actionCancel = UNNotificationAction(identifier: UserNotification.Action.Cancel, title: "Cancel", options: [])
        let reqVideoCallCategory = UNNotificationCategory(identifier: UserNotification.Category.RequestVideoCall, actions: [actionAccept,actionCancel], intentIdentifiers: [], options: [.customDismissAction])
        // Add to set
        notificationCategories.insert(reqVideoCallCategory)
        
        // Request open camera
        let actionOpen = UNNotificationAction(identifier: UserNotification.Action.Open, title: "Open", options: [.foreground])
        let actionClose = UNNotificationAction(identifier: UserNotification.Action.Close, title: "Close", options: [])
        let reqOpenCameraCategory = UNNotificationCategory(identifier: UserNotification.Category.RequestOpenCamera, actions: [actionOpen,actionClose], intentIdentifiers: [], options: [.customDismissAction])
//        // Add to set
        notificationCategories.insert(reqOpenCameraCategory)
        
        // Messaging
        let actionSend = UNTextInputNotificationAction(identifier: UserNotification.Action.Reply, title: "Reply", options: [], textInputButtonTitle: "Send", textInputPlaceholder: "Message...")
        let actionRead = UNNotificationAction(identifier: UserNotification.Action.MarkAsRead, title: "Mark as read", options: [])
        let incomingMsgCategory = UNNotificationCategory(identifier: UserNotification.Category.Message, actions: [actionSend,actionRead], intentIdentifiers: [], options: [.customDismissAction])
        // Add to set
        notificationCategories.insert(incomingMsgCategory)
        
        // Register category
        os_log("AppDelegate : Set notification category in notification center", log: log_app_debug, type: .debug)
        UNUserNotificationCenter.current().setNotificationCategories(notificationCategories)
        
        // Sel delegate to show notification when app is in foreground
        UNUserNotificationCenter.current().delegate = self
        
        // Request permission to send local notification
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            os_log("AppDelegate : User notifications permission : %@", log: log_app_debug, type: .debug, granted ? "allow" : "denied")
            guard granted else {
                os_log("AppDelegate : User not allow remote notification", log: log_app_error, type: .error)
                return
            }
            // If permission granted, Register for remote notification
            //self.registerRemoteNotifications()
        }
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
    
    /* Close missed call local notification with call */
    public func closeMessageReceivedLocalNotification(message: OpaquePointer) {
        // Get username
        let remoteAddr = sipUAManager.getMessageRemoteAddress(message: message)
        let username = SipUtils.getUsernameFromAddress(address: remoteAddr)!
        os_log("AppDelegate : Remove message received local notification from notification center", log: log_app_debug, type: .debug)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [UserNotification.Identifier.MessageReceived + username])
    }
    
}

// MARK: - Extension delegate for user notification
extension AppDelegate: UNUserNotificationCenterDelegate {
    // MARK: - Romote notification (Push Notification)
    // The result of calling registerForRemoteNotifications() function
    /* Register remote notification success */
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        os_log("AppDelegate : didRegisterForRemoteNotificationsWithDeviceToken", log: log_app_debug, type: .debug)
        os_log("AppDelegate : Register remote notification success", log: log_app_debug, type: .debug)
        let tmpToken = deviceToken.map({ (data) -> String in
            String(format: "%02.2hhx", data)
        }).joined()
        os_log("AppDelegate : Push notification token : %@", log: log_app_debug, type: .debug, tmpToken)
        sipUAManager.setPushNotificationToken(token: deviceToken)
    }
    
    /* Register remote notification failed */
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        os_log("AppDelegate : didFailToRegisterForRemoteNotificationsWithError", log: log_app_debug, type: .debug)
        os_log("AppDelegate : Register remote notification failed : %@", log: log_app_error, type: .error, error as CVarArg)
        sipUAManager.setPushNotificationToken(token: nil)
    }
    
    /* Remote notification received */
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        os_log("AppDelegate : Receive remote notification", log: log_app_debug, type: .debug)
        processPush(userInfo: userInfo, identifier: "Remote")
        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    // MARK: - Local notification
    /* This will be called when the notification action is tapped */
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        os_log("AppDelegate : Receive response action from notification", log: log_app_debug, type: .debug)
        
        let request = response.notification.request
        let requestContent = request.content
        let action = response.actionIdentifier
        os_log("AppDelegate : Action identifier : %@", log: log_app_debug, type: .debug, action)
        os_log("AppDelegate : Notification request identifier : %@", log: log_app_debug, type: .debug, request.identifier)
        os_log("AppDelegate : Notification request content category identifier : %@", log: log_app_debug, type: .debug, requestContent.categoryIdentifier)
        
        guard let callID = requestContent.userInfo["call-id"] as? String
            else {
                os_log("AppDelegate : Call id in user info is nil", log: log_app_error, type: .error)
                return
        }
        os_log("AppDelegate : Call id : %@", log: log_app_debug, type: .debug, callID)
        // MARK: - Calling
        if let call = sipUAManager.getCallFromCallID(callID: callID) {
            os_log("AppDelegate : Call id is call", log: log_app_debug, type: .debug)
            switch action {
            // MARK: Answer audio/video action
            case UserNotification.Action.AnswerAudio , UserNotification.Action.AnswerVideo :
                os_log("AppDelegate : Answer audio/video action from notification", log: log_app_debug, type: .debug)
                let answerVideo = (action == UserNotification.Action.AnswerVideo)  ? true : false
                if useCallKit {
                    // Check running call
                    // In case there is one running call, incoming call received, user tap answer action from local notification
                    // If no running call found that means two incoming call come
                    // and user tap answer call from local notification not from call native UI
                    if sipUAManager.countRunningCall() == 0 {
                        var callKitUUID: UUID?
                        //var callKitCall: OpaquePointer?
                        // End another call first
                        if Controller.getControllerCalls().count != 0 {
                            os_log("AppDelegate : All call in controller : %i", log: log_app_debug, type: .debug, Controller.getControllerCalls().count)
                            // Temporary keep outgoing CallKit uuid
                            callKitUUID = Controller.getControllerCalls().last?.uuid
                            //callKitCall = Controller.getControllerCalls().last?.call
                        }
                        // Start call
                        let uuid = UUID()
                        let callName = (sipUAManager.getRemoteDisplayName(call: call) ?? sipUAManager.getRemoteUsername(call: call)) ?? "Unknown"
                        os_log("AppDelegate : Start CallKit call name : %@", log: log_app_debug, type: .debug, callName)
                        // Set isOutgoing input to true for being called in call state change streams running
                        Controller.startCall(uuid: uuid, handle: callName, call: call, isVideo: answerVideo, isOutgoing: true)
                        if let uuid = callKitUUID /*, let call = callKitCall*/ {
                            // If outgoing call happen, There is incoming call come, User answer call from notification
                            if sipUAManager.countOutgoingCall() != 0 {
                                // Calling end CallKit later because provider callback function [Activate audio session and Deacivate audio session]
                                // are not called as sequence, Then we have to make sure that activate audio session called first
                                os_log("AppDelegate : End the previous CallKit and hangup a call", log: log_app_debug, type: .debug)
                                Controller.endCall(uuid: uuid)
                                // If no out going call (there are two incoming call come), User tap answer call from notification (the second call)
                                // that is not a call active with CallKit (showed by native UI) then we have to start CallKit with a second call
                                // and end CallKit with the first call (Switch CallKit to second call)
                            } else {
                                // Report call to end CallKit later because provider callback function [Activate audio session
                                // and Deacivate audio session] are not called as sequence,
                                // Then we have to make sure that activate audio session called first
                                os_log("AppDelegate : Report to end the previous CallKit", log: log_app_debug, type: .debug)
                                Provider.callProvider.reportCall(with: uuid, endedAt: nil, reason: .remoteEnded)
                                //Controller.removeCall(call: call)
                            }
                        }
                        // Answer call normally if found running call
                    } else {
                        sipUAManager.answer(call: call, withVideo: answerVideo)
                    }
                    // Answer call normally if not using CallKit
                } else {
                    sipUAManager.answer(call: call, withVideo: answerVideo)
                }
            // MARK: Decline action
            case UserNotification.Action.Decline :
                os_log("AppDelegate : Decline action from notification", log: log_app_debug, type: .debug)
                sipUAManager.decline(call: call)
            // MARK: Accept/open action
            case UserNotification.Action.Accept , UserNotification.Action.Open :
                os_log("AppDelegate : Accept/Open action from notification", log: log_app_debug, type: .debug)
                if let callingView = CallingView.viewControllerInstance() {
                    
//                    if callingView.toClass == AppView.ClassName.IncomingCall {
//                        // Dismiss popup
//                        callingView.closeAskingAcceptOpenCameraPopup()
//                        // Close local notification
//                        closeRequestOpenCameraLocalNotification(call: call)
//                        // Open camera
//                        sipUAManager.enableCamera(enable: true, captureView: callingView.videoCallSubView.captureView)
//                        // Set open camera status to use in AppDelegate class
//                        isCameraOpen = true
//                    } else
                     if callingView.toClass == AppView.ClassName.IncomingCall {
                        // Dismiss popup
//                        callingView.closeAskingAcceptVideoCallPopup()
                        // Close local notification
//                        closeRequestVideoCallLocalNotification(call: call)
                        // Accept call update
                        sipUAManager.acceptCallUpdate()
                        if useCallKit {
                            // CallKit
                            if let uuid = Controller.getUUID(call: call) {
                                Provider.updateCall(call: call, uuid: uuid)
                            } else {
                                os_log("AppDelegate : Can't get uuid from call to update by remote", log: log_app_error, type: .error)
                            }
                        }
                    }
                    
                } else {
                    os_log("AppDelegate : Can't get CallingView instance", log: log_app_error, type: .error)
                }
            // MARK: Cancel/close action
            case UserNotification.Action.Cancel , UserNotification.Action.Close :
                os_log("AppDelegate : Cancel/Close action from notification", log: log_app_debug, type: .debug)
                if let callingView = CallingView.viewControllerInstance() {
                    

                    if callingView.toClass == AppView.ClassName.IncomingCall {
                        
                        // Dismiss popup
//                        callingView.closeAskingAcceptVideoCallPopup()
                        // Close local notification
//                        closeRequestVideoCallLocalNotification(call: call)
                        // Refresh call to audio
                        sipUAManager.refreshCall()
                        if useCallKit {
                            // CallKit
                            if let uuid = Controller.getUUID(call: call) {
                                Provider.updateCall(call: call, uuid: uuid)
                            } else {
                                os_log("AppDelegate : Can't get uuid from call to update by remote", log: log_app_error, type: .error)
                            }
                        }
                    }
                    
                } else {
                    os_log("AppDelegate : Can't get CallingView instance", log: log_app_error, type: .error)
                }
            // MARK: Default action
            case UNNotificationDefaultActionIdentifier:
                os_log("AppDelegate : Default action from notification", log: log_app_debug, type: .debug)
            // MARK: Dismiss action
            case UNNotificationDismissActionIdentifier:
                os_log("AppDelegate : Dismiss action from notification", log: log_app_debug, type: .debug)
            default :
                os_log("AppDelegate : Action from notification is not in condition, Should handle it", log: log_app_debug, type: .debug)
            }
            // MARK: - Messaging
        } else {
            os_log("AppDelegate : Call id is not for call", log: log_app_debug, type: .debug)
            os_log("AppDelegate : Continue check call id with message", log: log_app_debug, type: .debug)
            if let message = sipUAManager.getMessageFromCallID(callID: callID) {
                os_log("AppDelegate : Call id is message", log: log_app_debug, type: .debug)
                let chatRoom = sipUAManager.getChatRoomFromMsg(message: message)
                os_log("AppDelegate : Get chat room", log: log_app_debug, type: .debug)
                switch action {
                // MARK: Reply action
                case UserNotification.Action.Reply :
                    os_log("AppDelegate : Reply action from notification", log: log_app_debug, type: .debug)
                    // Cast response to text input response type to get text
                    if let textResponse = response as? UNTextInputNotificationResponse {
                        let text = textResponse.userText
                        if text != "" && text.count != 0 && !text.isEmpty {
                            // Create message
                            let message = sipUAManager.createMessage(chatRoom: chatRoom, message: text)
                            // Send message
                            sipUAManager.sendMessage(message: message)
                        }
                        // Mark as read in case user not open the app if user open app mark as read will be called in setupChatConversation()
                        sipUAManager.markAsRead(chatRoom: chatRoom)
                        // Update unread message badge in main view
                        NotificationCenter.default.post(name: .appUpdateUI, object: nil)
                        // Close message received notification
                        closeMessageReceivedLocalNotification(message: message)
                    }
                // MARK: Mark as read action
                case UserNotification.Action.MarkAsRead :
                    os_log("AppDelegate : Mark as read action from notification", log: log_app_debug, type: .debug)
                    // Mark as read
                    sipUAManager.markAsRead(chatRoom: chatRoom)
                    // Update unread message badge in main view
                    NotificationCenter.default.post(name: .appUpdateUI, object: nil)
                    // Close message received notification
                    closeMessageReceivedLocalNotification(message: message)
                // MARK: Default action
                case UNNotificationDefaultActionIdentifier:
                    os_log("AppDelegate : Default action from notification", log: log_app_debug, type: .debug)
                    os_log("AppDelegate : Present chatting view or load subview", log: log_app_debug, type: .debug)
//                    let animate = UIApplication.shared.applicationState == .active ? true : false
//                    presentChattingView(chatRoom: chatRoom, animated: animate)
                    // Close message received notification
                    closeMessageReceivedLocalNotification(message: message)
                // MARK: Dismiss action
                case UNNotificationDismissActionIdentifier:
                    os_log("AppDelegate : Dismiss action from notification", log: log_app_debug, type: .debug)
                default :
                    os_log("AppDelegate : Action from notification is not in condition, Should handle it", log: log_app_debug, type: .debug)
                }
            } else {
                os_log("AppDelegate : Not found message from call id", log: log_app_debug, type: .debug)
            }
        }
        completionHandler()
    }
    /* To show notification even app in foreground with options */
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        os_log("AppDelegate : Push notification will present", log: log_app_debug, type: .debug)
        completionHandler([.alert, .badge])
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

// MARK: - Extension for transition effect
extension AppDelegate: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        // Prepare present transition animation
        transition.duration = 0.4
        transition.transitionMode = .present
        return transition
    }
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        // Prepare dismiss transition animation
        transition.duration = 0.4
        transition.transitionMode = .dismiss
        return transition
    }
}

