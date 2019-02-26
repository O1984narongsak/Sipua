
import CoreFoundation.CFString
import LinphoneModule
import SystemConfiguration
import SystemConfiguration.CaptiveNetwork
import CoreTelephony
import AVKit
import UserNotifications
import AudioToolbox

// MARK: - Compute global properties
/**
 Get the linphone core if created (a compute property).
 */
public var LC: OpaquePointer? {
    do {
        return try SipUAManager.instance().getLC()
    } catch CoreError.NilError {
        os_log("Can not get linphonecore : [nil]", log: log_manager_error, type: .error)
        return nil
    } catch CoreError.UnknownError {
        os_log("Can not get linphonecore : [unknown]", log: log_manager_error, type: .error)
        return nil
    } catch {
        os_log("Can not get linphonecore : [others]", log: log_manager_error, type: .error)
        return nil
    }
}

// MARK: - Global properties
/** String for chat db file. */
internal let kLinphoneInternalChatDBFilename = "linphone_chats.db"
/** Using for network connection. */
internal var proxyReachability: SCNetworkReachability?
/** Using for searching value in config file. */
internal let LINPHONERC_APPLICATION_KEY = "app"
/** Default string for camera ID. */
internal let FRONT_CAM_NAME = "AV Capture: com.apple.avfoundation.avcapturedevice.built-in_video:1"
internal let BACK_CAM_NAME = "AV Capture: com.apple.avfoundation.avcapturedevice.built-in_video:0"
/** String for proxy config reference key. */
internal let push_notification = "push_notiication"
internal let no_push_notification = "no_push_notiication"

// MARK: - Enumeration Connectivity
/**
 A custom enumerations of connection type.
 - parameters:
    - wifi: a connection is wifi.
    - wwan: a connection is wwan.
    - none: no connection.
 */
internal enum Connectivity {
    case wifi
    case wwan
    case none
}

// MARK: - Structure Call Context
/**
 A custom structure of linphone call. For temporary keep information before app go to background.
 - parameters:
    - call: a linphone call.
    - isVideoEnabled: a video status associate with a call.
 */
public struct CallContext {
    public var call: OpaquePointer?
    public var isVideoEnabled: Bool = false
}

// MARK: - Structure Payload type
/**
 A custom structure of linphone payload type.
 - parameters:
    - name: a name of payload type.
    - clock_rate: a clock rate of payload type.
    - channels: a channels of payload type.
 */
public struct SipPayloadType {
    public var name: String = ""
    public var clock_rate: Int = 0
    public var channels: Int = 0
}

// MARK: - Structure Video definition
/**
 A custom structure of linphone video definition.
 - parameters:
    - name: a name of video definition.
    - height: a height of video definition.
    - width: a width of video definition.
 */
public struct SipVideoDefinition {
    public var name: String = ""
    public var height: Int = 0
    public var width: Int = 0
}

// MARK: - Structure Call History
/**
 A custom structure of linphone call history.
 - parameters:
    - callDirection: a direction of call.
    - callStatus: a status of call.
    - callDuration: a duration of call.
    - isVideoCall: a video or audio call status.
    - callErrorInfo: a error reason of call.
    - callStartDate: a start date of call.
    - callWasConf: a conference call status.
    - callRemoteAddr: a remote address of call.
    - callLocalAddr: a local address of call.
    - callId: a call id of call.
 */
public struct SipCallHistoryDetails {
    public var callDirection: LinphoneCallDir?
    public var callStatus: LinphoneCallStatus?
    public var callDuration: Int = 0
    public var isVideoCall: Bool = false
    public var callErrorInfo: LinphoneReason?
    public var callStartDate: TimeInterval?
    public var callWasConf: Bool = false
    public var callRemoteAddr: OpaquePointer?
    public var callLocalAddr: OpaquePointer?
    public var callId: String = ""
}

// MARK: - Structure NetworkReachabilityContext
/**
 A custom structure of network reachability.
 - parameters:
    - testWifi: a wifi status.
    - testWWan: a wwan status.
    - networkStateChanged: a function pointer of network reachability.
 */
internal struct NetworkReachabilityContext {
    var testWifi,testWWan: Bool
    var networkStateChanged: UnsafeMutableRawPointer?
}

// MARK: - Enumeration of error
internal enum CoreError: Error {
    case NilError
    case UnknownError
}

// MARK: - Main class
/**
 SipUAManager class that is a main class for library,
 
 Must call SipUAManager.instance() to init this class then we can access a function.
 */
public class SipUAManager {
    
    // MARK: Properties
    /** Singleton (The static instance). */
    fileprivate static var sipUAInstance: SipUAManager?
    fileprivate static var libStarted: Bool = false
    
    /** Linphone properties. */
    var theLinphoneCore: OpaquePointer?
    var factory: OpaquePointer?
    var mCall: OpaquePointer?
    
    /** Network properties. */
    var SSID: String = ""
    var connectivity: Connectivity?
    
    /* Timer properties. */
    var iterateTimer: Timer?
    var vibrateTimer: Timer?
    
    /** Config properties. */
    var userConfigPath: String?
    var factoryConfigPath: String?
    var userConfigPathPt: UnsafePointer<Int8>?
    var factoryConfigPathPt: UnsafePointer<Int8>?
    var lpConfig: OpaquePointer?
    
    /** Sound path properties. */
    var ringTonePath: String?
    var ringBackPath: String?
    var ringHoldPath: String?
    
    /** Camera id properties. */
    var frontCamId: String = ""
    var backCamId: String = ""
    
    /** Register status properties. */
    var registerStatus: String = ""
    
    /** Device properties. */
    let device = UIDevice.current
    
    /** CallKit using status.
     For SipUAAudioManager to control audio mode when advance user wants to test. */
    var useCallKit: Bool = true
    
    /** Temporary domain to check realtime connection */
    var convertDomain: String?
    
    /** Paused call Background task. */
    var pausedCallBGTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    /** Push Call Background task. */
    var pushCallBGTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    /** Push Message Background task. */
    var pushMsgBGTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    /** Notification Token. */
    var pushNotificationToken: Data?
    /** Call before app go to background. */
    var callContext: CallContext?
    /** An array for keeping call id from push notification to show missed call or received message notification */
    var pushCalls: [String]?
    var pushMessages: [String]?
    
    // MARK: - Closure global state change
    let LinphoneGlobalStateChangeCb: LinphoneCoreCbsGlobalStateChangedCb = {
        (lc: OpaquePointer?, state: _LinphoneGlobalState, message: UnsafePointer<Int8>?)  in
        // Get user data(SipUAManager) from linphone, because in closure we can't use SipUAManager directly.
        let pointer = linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc))
        let userData = Unmanaged<SipUAManager>.fromOpaque(pointer!).takeUnretainedValue()
        // Send to function.
        userData.onGlobalStateChanged(state: state, message: message)
        // SipUAManager.instance().onGlobalStateChanged(gstate: gstate, message: message)
    }
    // MARK: - Closure configuration state change
    let LinphoneConfigStateChangeCb: LinphoneCoreCbsConfiguringStatusCb = {
        (lc: OpaquePointer?, state: _LinphoneConfiguringState, message: UnsafePointer<Int8>?) in
        // Get user data(SipUAManager) from linphone, because in closure we can't use SipUAManager directly.
        let pointer = linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc))
        let userData = Unmanaged<SipUAManager>.fromOpaque(pointer!).takeUnretainedValue()
        // Send to function.
        userData.onConfiguringStateChanged(state: state, message: message)
    }
    // MARK: - Closure register state change
    let LinphoneRegisterStateChangeCb: LinphoneCoreCbsRegistrationStateChangedCb = {
        (lc: OpaquePointer?, cfg: OpaquePointer?, state: _LinphoneRegistrationState, message: UnsafePointer<Int8>?) in
        // Get user data(SipUAManager) from linphone, because in closure we can't use SipUAManager directly.
        let pointer = linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc))
        let userData = Unmanaged<SipUAManager>.fromOpaque(pointer!).takeUnretainedValue()
        // Send to function.
        userData.onRegisterationStateChanged(cfg: cfg, state: state, message: message)
    }
    // MARK: - Closure call state change
    let LinphoneCallStateChangeCb: LinphoneCoreCbsCallStateChangedCb = {
        (lc: OpaquePointer?, call: OpaquePointer?, state: _LinphoneCallState, message: UnsafePointer<Int8>?) in
        // Get user data(SipUAManager) from linphone, because in closure we can't use SipUAManager directly.
        let pointer = linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc))
        let userData = Unmanaged<SipUAManager>.fromOpaque(pointer!).takeUnretainedValue()
        // Send to function.
        userData.onCallStateChanged(call: call, state: state, message: message)
    }
    // MARK: - Closure message receive state change
    let LinphoneMessageReceivedCb: LinphoneCoreCbsMessageReceivedCb = {
        (lc: OpaquePointer?, chatRoom: OpaquePointer?, message: OpaquePointer?) in
        // Get user data(SipUAManager) from linphone, because in closure we can't use SipUAManager directly.
        let pointer = linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc))
        let userData = Unmanaged<SipUAManager>.fromOpaque(pointer!).takeUnretainedValue()
        // Send to function.
        userData.onMessageReceived(lc: lc, chatRoom: chatRoom, message: message)
    }
    // MARK: - Closure message composing state change
    let LinphoneIsComposingReceivedCb: LinphoneCoreCbsIsComposingReceivedCb = {
        (lc: OpaquePointer?, chatRoom: OpaquePointer?) in
        // Get user data(SipUAManager) from linphone, because in closure we can't use SipUAManager directly.
        let pointer = linphone_core_cbs_get_user_data(linphone_core_get_current_callbacks(lc))
        let userData = Unmanaged<SipUAManager>.fromOpaque(pointer!).takeUnretainedValue()
        // Send to function.
        userData.onMessageComposingReceived(lc: lc, chatRoom: chatRoom)
    }
    // MARK: - Closure message status state change
    let LinphoneMessageStateChangeCb: LinphoneChatMessageCbsMsgStateChangedCb = {
        (message: OpaquePointer?, messageState: _LinphoneChatMessageState) in
        // Get user data(SipUAManager) from linphone, because in closure we can't use SipUAManager directly.
        let pointer = linphone_chat_message_get_user_data(message)
        let userData = Unmanaged<SipUAManager>.fromOpaque(pointer!).takeUnretainedValue()
        // Send to function.
        userData.onMessageStateChange(message: message, messageState: messageState)
    }
    
    // MARK: - Closure network reachability state change
    let NetworkReachabilityCb: SCNetworkReachabilityCallBack = {
        (target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: Optional<UnsafeMutableRawPointer>) in
        
        // Get class instance.
        let sipMgr: SipUAManager = SipUAManager.instance()
        // Show current network flags.
        sipMgr.ShowNetworkFlags(flags)
        // Collect network down flags.
        let networkDownFlags = SCNetworkReachabilityFlags.connectionRequired.rawValue |
                            SCNetworkReachabilityFlags.connectionOnTraffic.rawValue |
                            SCNetworkReachabilityFlags.connectionOnDemand.rawValue
        
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        
        // Get default proxy config.
        let proxyCfg = linphone_core_get_default_proxy_config(sipMgr.theLinphoneCore)
        var ctx: NetworkReachabilityContext?
        
        // If info is not nil then uwrap and cast to our NetworkReachabilityContext.
        if let unwrapCtx = info {
            var tempCtx = unwrapCtx
            var localTempCtx = tempCtx
            ctx = withUnsafeMutablePointer(to: &localTempCtx, {
                $0.withMemoryRebound(to: NetworkReachabilityContext.self, capacity: MemoryLayout.size(ofValue: tempCtx), {
                    $0.pointee
                })
            })
        } else {
            ctx = nil
        }
        
        // Debug to see NetworkReachabilityContext.
        if ctx != nil {
            os_log("NetworkReachabilityContext : testWifi : %@", log: log_manager_debug, type: .debug, ctx!.testWifi ? "true" : "false")
            os_log("NetworkReachabilityContext : testWWan : %@", log: log_manager_debug, type: .debug, ctx!.testWWan ? "true" : "false")
        }  else {
            os_log("NetworkReachabilityContext : nil", log: log_manager_debug, type: .debug)
        }
        
        // If there is no network flags or the bitewise result of network flags and network flags down is true.
        if (flags.rawValue == 0) || Int(flags.rawValue & networkDownFlags).boolValue {
            os_log("No network flag or network flag is down", log: log_manager_debug, type: .debug)
            // Set linphone network reachability to false.
            linphone_core_set_network_reachable(sipMgr.theLinphoneCore, UInt8(false.intValue))
            // Set connectivity type to none.
            sipMgr.connectivity = Connectivity.none
            // Kick off connection
             sipMgr.kickOffNetworkConnection()
            // If there is some network.
        } else {
            // Property for new connection.
            var newConnectivity: Connectivity
            // Read value from config file, If we using wifi only or not.
            var isWifiOnly = sipMgr.lpConfigGetBoolForKey(key: "wifi_only_preference", section: LINPHONERC_APPLICATION_KEY, defaultValue: false)
            os_log("Using wifi only : %@", log: log_manager_debug, type: .debug, isWifiOnly ? "true" : "false")
            
            // If NetworkReachabilityContext has value.
            if ctx != nil || ctx?.testWWan != nil {
                // Check network flags again to define connection is wifi or wwan.
                newConnectivity = Int(flags.rawValue & SCNetworkReachabilityFlags.isWWAN.rawValue).boolValue ? Connectivity.wwan : Connectivity.wifi
                os_log("Network reachability context(Netwotk state change) : %@", log: log_manager_debug, type: .debug, ctx?.networkStateChanged as! CVarArg)
            // If NetworkReachabilityContext has no value, Assume connection to wifi.
            } else {
                newConnectivity = Connectivity.wifi
            }
            
            // Check new connection, proxy config, wifi from config, old connection.
            if (newConnectivity == Connectivity.wwan) && (proxyCfg != nil) && isWifiOnly && ((sipMgr.connectivity == newConnectivity) || (sipMgr.connectivity == Connectivity.none)) {
                // Set proxy config expire time to 0.
                linphone_proxy_config_set_expires(proxyCfg, 0)
                os_log("Set proxy config expire to 0", log: log_manager_debug, type: .debug)
                // Check proxy config is not null.
            } else if proxyCfg != nil {
                // Read default proxy expire from config.
                var defaultExpire = sipMgr.lpConfigGetIntForKey(key: "default_expires", section: LINPHONERC_APPLICATION_KEY, defaultValue: -1)
                if defaultExpire >= 0 {
                    os_log("Set proxy config expire to default expire", log: log_manager_debug, type: .debug)
                    // Set proxy config expire time from config.
                    linphone_proxy_config_set_expires(proxyCfg, Int32(defaultExpire))
                }
            }
            
            // If connection has changed.
            if sipMgr.connectivity != newConnectivity {
                // Reset network reachable.
                linphone_core_set_network_reachable(sipMgr.theLinphoneCore, UInt8(false.intValue))
                // if wifi connection only is enabled but connection is wireless wide area network(cellular network),
                // Set proxy config expire time to 0.
                if newConnectivity == Connectivity.wwan && proxyCfg != nil && isWifiOnly {
                    linphone_proxy_config_set_expires(proxyCfg, 0)
                }
                linphone_core_set_network_reachable(sipMgr.theLinphoneCore, UInt8(true.intValue))
                // Refresh linphonecore once for network connection change.
                linphone_core_iterate(sipMgr.theLinphoneCore)
                os_log("Network connectivity changed to type [%@]", log: log_manager_debug, type: .debug, newConnectivity == Connectivity.wifi ? "wifi" : "wwan")
                // Update current connectivity.
                sipMgr.connectivity = newConnectivity
            }
        }
        
        // Update connectivity to NetworkReachabilityContext.
        if ctx != nil && ctx?.networkStateChanged != nil {
            ctx?.networkStateChanged?.assumingMemoryBound(to: Connectivity.self).pointee =  sipMgr.connectivity!
        }
        
    }
    // MARK: - Closure network notification state change
    let NetworkReachabilityNotification: CFNotificationCallback = {
        (center: Optional<CFNotificationCenter>, observer: Optional<UnsafeMutableRawPointer>, name: Optional<CFNotificationName>,
        object: Optional<UnsafeRawPointer>, userInfo: Optional<CFDictionary>) in
        
        // Initialize network flags.
        var flags = SCNetworkReachabilityFlags()
        // Get SipUAManager class instance.
        var sipMgr = SipUAManager.instance()
        
        // For an unknown reason, We are receiving multiple time the notification.
        // We will skip each time if the SSID did not change.
        var newSSID = SipNetworkManager.getCurrentWifiSSID()
        if newSSID == sipMgr.SSID {
            return
        }
        
        // If new wifi name and current wifi name is not null.
        if (newSSID != "" && sipMgr.SSID != "") && (newSSID.count > 0 && sipMgr.SSID.count > 0) {
                if (SCNetworkReachabilityGetFlags(proxyReachability!, &flags)) {
                    os_log("Wifi SSID changed, Reseting transports", log: log_manager_debug, type: .debug)
                    // This will trigger a connectivity change in NetworkReachabilityCb.
                    sipMgr.connectivity = Connectivity.none
                    sipMgr.NetworkReachabilityCb(proxyReachability!, flags, nil)
                }
        }
        
        // Update new wifi name to current wifi name.
        sipMgr.SSID = newSSID
        
    }
    // MARK: - Closure network flags
    let ShowNetworkFlags = { (flags: SCNetworkReachabilityFlags) in
        
        // Print network flags.
        var log: String = "Network connection flags : "
        if flags.rawValue == 0 {
            log.append("No flags")
        }
        if Int(flags.rawValue & SCNetworkReachabilityFlags.transientConnection.rawValue).boolValue {
            log.append("kSCNetworkReachabilityFlagsTransientConnection, ")
        }
        if Int(flags.rawValue & SCNetworkReachabilityFlags.reachable.rawValue).boolValue {
            log.append("kSCNetworkReachabilityFlagsReachable, ")
        }
        if Int(flags.rawValue & SCNetworkReachabilityFlags.connectionRequired.rawValue).boolValue {
            log.append("kSCNetworkReachabilityFlagsConnectionRequired, ")
        }
        if Int(flags.rawValue & SCNetworkReachabilityFlags.connectionOnTraffic.rawValue).boolValue {
            log.append("kSCNetworkReachabilityFlagsConnectionOnTraffic, ")
        }
        if Int(flags.rawValue & SCNetworkReachabilityFlags.connectionOnDemand.rawValue).boolValue {
            log.append("kSCNetworkReachabilityFlagsConnectionOnDemand, ")
        }
        if Int(flags.rawValue & SCNetworkReachabilityFlags.isLocalAddress.rawValue).boolValue {
            log.append("kSCNetworkReachabilityFlagsIsLocalAddress, ")
        }
        if Int(flags.rawValue & SCNetworkReachabilityFlags.isDirect.rawValue).boolValue {
            log.append("kSCNetworkReachabilityFlagsIsDirect, ")
        }
        if Int(flags.rawValue & SCNetworkReachabilityFlags.isWWAN.rawValue).boolValue {
            log.append("kSCNetworkReachabilityFlagsIsWWAN, ")
        }
        os_log("%@", log: log_manager_debug, type: .debug, log)
        
    }
    
    
    // MARK: - SipUAManager instance
    /**
     Get SipUAManager instance.
     - returns: an SipUAManager instance.
     */
    public static func instance() -> SipUAManager {
        
        if sipUAInstance == nil {
            // Initial SipUAManager using closure.
            sipUAInstance = synchronized(lock: SipUAManager.self) {
                return SipUAManager()
            }
        }
        return sipUAInstance!
            
    }
    
    /* Using for lock the task to initial SipUAManager */
    fileprivate static func synchronized(lock: Any, closure: () -> SipUAManager) -> SipUAManager  {
        
        var tmpInstance: SipUAManager
        
        // Lock thread until working finish.
        objc_sync_enter(lock)
        tmpInstance = closure()
        // Unlock thread.
        objc_sync_exit(lock)
        
        return tmpInstance
    }
    
    // MARK: - Class initialization
    /* Initial class */
    fileprivate init() {
        os_log("SipUAManager initializing...", log: log_manager_debug, type: .debug)
        
        // Initial properties.
        callContext = CallContext()
        pushCalls = [String]()
        pushMessages = [String]()
        
        // Create linphone config and prepare resources.
        renameDefaultSettings()
        copyDefaultSettings()
        overrideDefaultSettings()
    }
    
    /**
     Check the SipUAManager class is initialized or not.
     - returns:
     
        true, If class is already init.
     
        false, If class is not init.
     */
    public func isInstanciated() -> Bool {
        if SipUAManager.sipUAInstance == nil {
            return false
        }
        return true
    }
    
    /**
     Start linphonecore and set other things.
     */
    public func initSipUAManager() {
        if isInstanciated() {
            os_log("Start linphonecore.", log: log_manager_debug, type: .debug)
            startLinphoneCore()
        } else {
            os_log("SipUAManager is not create yet. Please run SipUAManager.instance()", log: log_manager_error, type: .error)
            return
        }
    }
    
    // MARK: - Linphonecore
    /* Start the linphonecore */
    fileprivate func startLinphoneCore() {
        
        // Checking library is started.
        if (SipUAManager.libStarted) {
            os_log("Liblinphone is already initialized", log: log_manager_debug, type: .debug)
            return
        }
        
        // Set library start flag to true.
        SipUAManager.libStarted = true
        
        // Set default connectivity type.
        connectivity = Connectivity.none
        
        // Ignore the signal SIGPIPE to prevent a program closing.
        signal(SIGPIPE, SIG_IGN)
        
        // Create linphonecore.
        createLinphoneCore()
        
        // Config audio session.
        SipAudioManager.config()
        // Start handle audio manager.
        os_log("Add Observer for audio route change/interrupt", log: log_manager_debug, type: .debug)
        SipAudioManager.registerForAudioRouteChangeNotification()
        
        if UIApplication.shared.applicationState == UIApplication.State.background {
            os_log("Application is not in foreground, Enter background mode", log: log_manager_debug, type: .debug)
            // Go to back ground mode
            enterBackgroundMode()
        }
        
    }
    
    /* Create linphonecore */
    fileprivate func createLinphoneCore() {
        
        // Check linphonecore is created.
        if theLinphoneCore != nil {
            os_log("LinphoneCore is already created...", log: log_manager_debug, type: .debug)
            return
        }
        
        // Enable linphone log.
        let enable = UInt32(lpConfigGetIntForKey(key: "debugenable_preference", section: LINPHONERC_APPLICATION_KEY, defaultValue:1))
        let logLevel = BctbxLogLevel.init(enable)
        SipLog.enableLogs(level: logLevel)
        
        // Set default connectivity type.
        connectivity = Connectivity.none
        
        // Get sound path from config.
        ringTonePath = lpConfigGetStringForKey(key: "local_ring", section: "sound", defaultValue: nil)
        os_log("Ringtone path from config : %@", log: log_manager_debug, type: .debug, ringTonePath ?? "nil")
        // To make sure the resource file is exist.
        var ringSound: String?
        ringSound = ringTonePath != nil ? bundleFile(file: (ringTonePath! as NSString).lastPathComponent) : bundleFile(file: "ringtone.wav")
        // Unwrap sound path.
        if let unwrapRingSound = ringSound {
            // Save sound path to config.
            os_log("Save ringtone sound to config : %@", log: log_manager_debug, type: .debug, unwrapRingSound)
            lpConfigSetStringForKey(value: bundleFile(file: (unwrapRingSound as NSString).lastPathComponent), key: "local_ring", section: "sound")
        } else {
            os_log("Sound file does not exist", log: log_manager_error, type: .error)
        }
        
        // Get sound path from config.
        ringBackPath = lpConfigGetStringForKey(key: "remote_ring", section: "sound", defaultValue: nil)
        os_log("Ringback path from config : %@", log: log_manager_debug, type: .debug, ringBackPath ?? "nil")
        // To make sure the resource file is exist.
        var ringBackSound: String?
        ringBackSound = ringBackPath != nil ? bundleFile(file: (ringBackPath! as NSString).lastPathComponent) : bundleFile(file: "ringback.wav")
        // Unwrap sound path.
        if let unwrapRingBackSound = ringBackSound {
            // Save sound path to config.
            os_log("Save ringback sound to config : %@", log: log_manager_debug, type: .debug, unwrapRingBackSound)
            lpConfigSetStringForKey(value: bundleFile(file: (unwrapRingBackSound as NSString).lastPathComponent), key: "remote_ring", section: "sound")
        } else {
            os_log("Sound file does not exist", log: log_manager_error, type: .error)
        }
        
        // Get sound path from config.
        ringHoldPath = lpConfigGetStringForKey(key: "hold_music", section: "sound", defaultValue: nil)
        os_log("Ringhold path from config : %@", log: log_manager_debug, type: .debug, ringHoldPath ?? "nil")
        // To make sure the resource file is exist.
        var ringHoldSound: String?
        ringHoldSound = ringHoldPath != nil ? bundleFile(file: (ringHoldPath! as NSString).lastPathComponent) : bundleFile(file: "ringhold.wav")
        // Unwrap sound path.
        if let unwrapRingHoldSound = ringHoldSound {
            // Save sound path to config.
            os_log("Save ringhold sound to config : %@", log: log_manager_debug, type: .debug, unwrapRingHoldSound)
            lpConfigSetStringForKey(value: bundleFile(file: (unwrapRingHoldSound as NSString).lastPathComponent), key: "hold_music", section: "sound")
        } else {
            os_log("Sound file does not exist", log: log_manager_error, type: .error)
        }
        
        // Create a linphone factory.
        factory = linphone_factory_get()
        
        // Create linphone callback.
        let callBack = linphone_factory_create_core_cbs(factory)
        
        // Set global state callback to linphone callback.
        linphone_core_cbs_set_global_state_changed(callBack, LinphoneGlobalStateChangeCb)
        // Set config state callback to linphone callback.
        linphone_core_cbs_set_configuring_status(callBack, LinphoneConfigStateChangeCb)
        // Set register state callback to linphone callback.
        linphone_core_cbs_set_registration_state_changed(callBack, LinphoneRegisterStateChangeCb)
        // Set call state callback to linphone callback.
        linphone_core_cbs_set_call_state_changed(callBack, LinphoneCallStateChangeCb)
        // Set message received callback to linphone callback.
        linphone_core_cbs_set_message_received(callBack, LinphoneMessageReceivedCb)
        // Set composing received callback to linphone callback.
        linphone_core_cbs_set_is_composing_received(callBack, LinphoneIsComposingReceivedCb)
        
        // Set user data callback to linphone callback. We will using it in closure.
        linphone_core_cbs_set_user_data(callBack, bridgeRetained(obj: self))

        // Create linphone core.
        if lpConfig == nil {
            // Create linphone config and prepare resources.
            renameDefaultSettings()
            copyDefaultSettings()
            overrideDefaultSettings()
        }
        theLinphoneCore = linphone_factory_create_core_with_config_3(factory, lpConfig, nil)
        
        // Add callback.
        linphone_core_add_callbacks(theLinphoneCore, callBack);
        
        // Start core.
        linphone_core_start(theLinphoneCore);
        
        // Let the core handle callback by unreference callback.
        linphone_core_cbs_unref(callBack)
        
        os_log("Created linphonecore : %@", log: log_manager_debug, type: .debug, (theLinphoneCore?.debugDescription)!)
        
        // Load dynamic plugin, If not found it will do nothing.
        if let msFactory = linphone_core_get_ms_factory(theLinphoneCore) {
            libmssilk_init(msFactory)
            libmsamr_init(msFactory)
            libmsx264_init(msFactory)
            libmsopenh264_init(msFactory)
            libmswebrtc_init(msFactory)
            libmscodec2_init(msFactory)
            linphone_core_reload_ms_plugins(theLinphoneCore, nil)
        }
        
        // Get sound path from config and set to linphone core.
        ringTonePath = lpConfigGetStringForKey(key: "local_ring", section: "sound", defaultValue: nil)
        if ringTonePath != nil {
            let ringTonePt = ringTonePath!.stringToUnsafePointerInt8()
            linphone_core_set_ring(theLinphoneCore, ringTonePt)
        } else { os_log("Ring tone path is nil", log: log_manager_debug, type: .debug) }
        ringBackPath = lpConfigGetStringForKey(key: "remote_ring", section: "sound", defaultValue: nil)
        if ringBackPath != nil {
            let ringBackPt = ringBackPath!.stringToUnsafePointerInt8()
            linphone_core_set_ringback(theLinphoneCore, ringBackPt)
        } else { os_log("Ring back path is nil", log: log_manager_debug, type: .debug) }
        ringHoldPath = lpConfigGetStringForKey(key: "hold_music", section: "sound", defaultValue: nil)
        if ringHoldPath != nil {
            let ringPausePt = ringHoldPath!.stringToUnsafePointerInt8()
            linphone_core_set_play_file(theLinphoneCore, ringPausePt)
        } else { os_log("Ring hold path is nil", log: log_manager_debug, type: .debug) }
        
        
        // Set root CA and user certification path(in case dtls transport type).
        if let unwrapRootCA = bundleFile(file: "rootca.pem") {
            let unwrapRootCAPt = unwrapRootCA.stringToUnsafePointerInt8()
            linphone_core_set_root_ca(theLinphoneCore, unwrapRootCAPt)
        } else {
            os_log("Can not set rootCA file", log: log_manager_error, type: .error)
        }
        linphone_core_set_user_certificates_path(theLinphoneCore, cacheDirectory())
        
        // Add observer to get notification from linphone
        NotificationCenter.default.addObserver(self, selector: #selector(globalStateChangedNotificationHandler), name: .kLinphoneGlobalStateUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(configuringStateChangedNotificationHandler), name: .kLinphoneConfiguringStateUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(registerStateChangedNotificationHandler), name: .kLinphoneRegistrationStateUpdate, object: nil)
        
        // Refresh linphonecore once.
        iterate()
        
        // Start iterate linphonecore with timer.
        iterateTimer = Timer.scheduledTimer(timeInterval: 0.02, target: self, selector: #selector(iterate), userInfo: nil, repeats: true)
        
    }
    
    /* Iterate linphonecore */
    @objc func iterate() {
        var coreIterateTaskId: UIBackgroundTaskIdentifier = .invalid
        coreIterateTaskId = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            os_log("Background task for core iteration expired", log: log_manager_debug, type: .debug)
            UIApplication.shared.endBackgroundTask(coreIterateTaskId)
        })
        linphone_core_iterate(theLinphoneCore)
        if coreIterateTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(coreIterateTaskId)
        }
    }
    
    /**
     Destroy the linphonecore.
     */
    public func destroyLinphoneCore() {
        
        // Stop timer.
        if iterateTimer != nil {
            iterateTimer?.invalidate()
            iterateTimer = nil
        }
        
        // Stop handle audio manager.
        os_log("Romove Observer for audio route change/interrupt", log: log_manager_debug, type: .debug)
        SipAudioManager.deregisterFromAudioRouteChangeNotification()
        
        // Destroy linphonecore.
        if theLinphoneCore != nil {
            linphone_core_unref(theLinphoneCore)
            os_log("Destroy LinphoneCore...", log: log_manager_debug, type: .debug)
            theLinphoneCore = nil
        }
        
        // Post notification.
        let dict: [AnyHashable:Any]
        if let unwrapCore = theLinphoneCore {
            dict = ["core" : unwrapCore]
        } else {
            dict = ["core" : ""]
        }
        NotificationCenter.default.post(name: .kLinphoneCoreUpdate, object: self, userInfo: dict)
        
        // Stop network listener.
        SCNetworkReachabilityUnscheduleFromRunLoop(proxyReachability!, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        if proxyReachability != nil {
            proxyReachability = nil
        }
    
        // Set library start flag to false.
        SipUAManager.libStarted = false
        
        // Remove all notification.
        NotificationCenter.default.removeObserver(self)
        
    }
    
    /**
     Get the linphonecore.
     - returns: a linphone core.
     */
    public func getLC() throws -> OpaquePointer {
        
        guard theLinphoneCore != nil else {
            os_log("The linphone core is nil", log: log_manager_error, type: .error)
            // Throw error if linphonecore is nil.
            throw CoreError.NilError
        }
        return theLinphoneCore!
        
    }
    
    // MARK: - Register
    /**
     Register to sip server.
     - parameters:
        - displayName: a display name of your register account as string.
        - userID: a user id as string, It will use for creating an authenticate info, Can be nil.
        - username: a username to register as string.
        - password: a password for a user name as string.
        - domain: a domain to register as string.
        - port: a port number as int.
        - destination: a destination for a proxy to change route of register message, Can be nil (it will be set the same as domain).
        - transport: a transport type (udp, tcp, tls) as string.
     */
    public func register(displayName: String?, userID: String?, username: String?, password: String?, domain: String?, port: Int?, destination: String?, transport: String?) {
        
        // Check SipUAManager is already initialize.
        if isInstanciated() && LC != nil {
            
            // Find default config to register
            let shouldCheckDefaultCfg = ((username == nil) && (password == nil) && (domain == nil))
            if shouldCheckDefaultCfg {
                os_log("Username, Password, Domain are nil, Check default proxy config to register", log: log_manager_debug, type: .debug)
                if let defaultCfg = linphone_core_get_default_proxy_config(theLinphoneCore) {
                    os_log("Found default proxy config to register", log: log_manager_debug, type: .debug)
                    enableRegister(config: defaultCfg)
                    return
                } else {
                    os_log("No default proxy config set", log: log_manager_debug, type: .debug)
                }
            }
            
            // Check string for nil.
            guard username != nil && username != "" && username!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) != ""
                else {
                    os_log("Username is nil", log: log_manager_error, type: .error)
                    return
            }
            guard password != nil && password != "" && password!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) != ""
                else {
                    os_log("Password is nil", log: log_manager_error, type: .error)
                    return
            }
            guard domain != nil && domain != "" && domain!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) != ""
                else {
                    os_log("Domain is nil", log: log_manager_error, type: .error)
                    return
            }
            
            // Check existing proxy config to register, In case user send the same value to register.
            var tmpPort = 0
            if port == nil {
                tmpPort = 5060
            } else {
                tmpPort = port!
            }
            if let savedConfig = checkConfigExist(username: username!, domain: domain!, port: tmpPort) {
                os_log("Config is already created, Using match config", log: log_manager_debug, type: .debug)
                enableRegister(config: savedConfig)
                return
            }
            
            // Set public domain name to use in kickOffNetworkConnection function.
            convertDomain = domain
            
            // Check string is nil if trim white space and new line.
            if username!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "" ||
                password!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "" ||
                domain!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "" {
                os_log("Value is nil after trim white space and new line", log: log_manager_error, type: .error)
                return
            }
            
            // Trim space and new line.
            let tmpUsername: String = username!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let tmpPassword: String = password!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let tmpDomain: String = domain!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // Create identity and proxy (destination).
            let identty: String = "sip:" + tmpUsername + "@" + tmpDomain
            var proxy: String = "sip:"
            if destination == nil || destination == "" {
                proxy = proxy + tmpDomain
            } else {
                if !destination!.starts(with: "sip:") && !destination!.starts(with: "<sip:") &&
                    !destination!.starts(with: "sips:") && !destination!.starts(with: "<sips:") {
                    proxy = proxy + destination!
                } else {
                    proxy = destination!
                }
            }
            
            os_log("Proxy Address : %@", log: log_manager_debug, type: .debug, proxy)
            os_log("Identity Address : %@", log: log_manager_debug, type: .debug, identty)
            
            // Create linphone address with proxy(sip:XXXXX) and identity(sip:XXXXX@YYYYY).
            let proxyAddr = linphone_address_new(proxy.stringToUnsafePointerInt8())
            let identityAddr = linphone_address_new(identty.stringToUnsafePointerInt8())
            
            // Set display name to identity.
            if displayName != nil && displayName != "" {
                linphone_address_set_display_name(identityAddr, displayName!.stringToUnsafePointerInt8())
            }
            
            // Set transport type to proxy.
            if transport != nil && transport != "" {
                if transport!.lowercased().contains("udp") {
                    linphone_address_set_transport(proxyAddr, LinphoneTransportUdp)
                } else if transport!.lowercased().contains("tcp") {
                    linphone_address_set_transport(proxyAddr, LinphoneTransportTcp)
                } else {
                    linphone_address_set_transport(proxyAddr, LinphoneTransportTls)
                }
            } else {
                linphone_address_set_transport(proxyAddr, LinphoneTransportUdp)
            }
            
            // Set port to proxy and identity.
            if port != nil {
                linphone_address_set_port(proxyAddr, (port! as NSNumber).int32Value)
                linphone_address_set_port(identityAddr, (port! as NSNumber).int32Value)
            } else {
                linphone_address_set_port(proxyAddr, 5060)
                linphone_address_set_port(identityAddr, 5060)
            }
            
            // Create proxy config.
            let prxCfg = linphone_core_create_proxy_config(theLinphoneCore)
            
            // Set identity address to proxy config.
            linphone_proxy_config_set_identity_address(prxCfg, identityAddr)
            
            // Set route and server address.
            let transportProxy = String(cString: linphone_transport_to_string(linphone_address_get_transport(proxyAddr))).lowercased()
            let domainProxy = String(cString: linphone_address_get_domain(proxyAddr))
            let domainIdentity = String(cString: linphone_address_get_domain(identityAddr))
            os_log("Transport type from proxy address : %@", log: log_manager_debug, type: .debug, transportProxy)
            os_log("Domain from proxy address : %@", log: log_manager_debug, type: .debug, domainProxy)
            os_log("Domain from identity address : %@", log: log_manager_debug, type: .debug, domainIdentity)
            let route = String(format: "%@;transport=%@", domainProxy, transportProxy)
            linphone_proxy_config_set_route(prxCfg, route.stringToUnsafePointerInt8())
            linphone_proxy_config_set_server_addr(prxCfg, route.stringToUnsafePointerInt8())
            
            // Enable the proxy config to register.
            linphone_proxy_config_enable_register(prxCfg, UInt8(true.intValue))
            
            // Enable publish message.
            linphone_proxy_config_enable_publish(prxCfg, UInt8(false.intValue))
            
            // Set expire time for register.
            linphone_proxy_config_set_expires(prxCfg, 3600)
            
            // Set RTCP-Feedback Message mode.
            linphone_proxy_config_set_avpf_mode(prxCfg, LinphoneAVPFDisabled)
            
            // Set RTCP-Feedback Message interval.
            linphone_proxy_config_set_avpf_rr_interval(prxCfg, UInt8(0))
            
            // Create authenticate info.
            let authInfo = linphone_auth_info_new(linphone_address_get_username(identityAddr)/*Username*/,
                                                  nil/*UserID*/,
                                                  tmpPassword.stringToUnsafePointerInt8()/*Password*/,
                                                  nil/*Ha1*/,
                                                  linphone_address_get_domain(identityAddr)/*Realm, Assume to be domain*/,
                                                  linphone_address_get_domain(identityAddr)/*Domain*/)
            
            // Set userID to authenticate if need.
            if userID != nil && userID != "" {
                linphone_auth_info_set_userid(authInfo, userID!.stringToUnsafePointerInt8())
            }
            
            // Add authenticate info to linphone.
            linphone_core_add_auth_info(theLinphoneCore, authInfo)
            
            // Unreference linphone address and auth info.
            linphone_address_unref(identityAddr)
            linphone_address_unref(proxyAddr)
            linphone_auth_info_unref(authInfo)
            
            // Add proxy config to linphonecore.
            if prxCfg != nil {
                if linphone_core_add_proxy_config(theLinphoneCore, prxCfg) != -1 {
                    // Set proxy config as a default proxy config.
                    linphone_core_set_default_proxy_config(theLinphoneCore, prxCfg)
                    // Turn on push notification for default proxy config.
                    enablePushNotification(enable: true)
                    // Set token to default proxy config.
                    configurePushTokenForProxyConfig(proxyConfig: prxCfg!)
                    os_log("Add proxy config, set default proxy config, enable push notification success", log: log_manager_debug, type: .debug)
                    for anotherConfig in getAllConfigs() where anotherConfig != prxCfg {
                        // Disable register.
                        linphone_proxy_config_enable_register(anotherConfig, UInt8(false.intValue))
                        // Disable push notification.
                        enablePushNotification(config: anotherConfig!, enable: false)
                        os_log("Disable register and push notification to user : %@", log: log_manager_debug, type: .debug, SipUtils.getIdentityUsernameFromConfig(config: anotherConfig!)!)
                    }
                } else {
                    os_log("Add proxy config failed", log: log_manager_error, type: .error)
                }
                // Unreference proxy config.
                linphone_proxy_config_unref(prxCfg)
            } else {
                os_log("Create proxy config failed", log: log_manager_error, type: .error)
                return
            }
        } else {
            os_log("Please initialize SipUAManager first!!", log: log_manager_error, type: .error)
            return
        }
        
    }
    
    /**
     Get register status.
     - returns:
        a register status as string.
     
            1. Not registered
     
            2. Registration in progress
     
            3. Registered
     
            4. Registration cleared
     
            5. Registration failed
     
            6. Not connected
     */
    public func getRegisterStatus() -> String {
        return registerStatus
    }
    
    /**
     Refresh register and refresh network reachability.
     */
    public func refreshRegister() {
        if (connectivity == Connectivity.none) {
            // Don't trust ios when he says there is no network. Create a new reachability context, the previous one might be mis-functionning.
            os_log("None connectivity, Setup network reachability callback", log: log_manager_debug, type: .debug)
            setupNetworkReachabilityCallback()
        }
        os_log("Network reachability callback is setup", log: log_manager_debug, type: .debug)
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        // Make sure register is up to date.
        linphone_core_refresh_registers(theLinphoneCore)
        os_log("Refresh register...", log: log_manager_debug, type: .debug)
        
    }
    
    /* Delete one by one for all configs */
    public func clearAllConfigs() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        
        os_log("=== Before Remove Config & Account ===", log: log_manager_debug, type: .debug)
        os_log("Count proxy config list : %i", log: log_manager_debug, type: .debug, bctbx_list_size(linphone_core_get_proxy_config_list(theLinphoneCore)))
        os_log("Count authenticate info list : %i", log: log_manager_debug, type: .debug, bctbx_list_size(linphone_core_get_auth_info_list(theLinphoneCore)))
        
        // Get proxy config list.
        let prxCfgList = linphone_core_get_proxy_config_list(theLinphoneCore)
        
        // Check proxy config list and remove each one.
        var prxCfg = prxCfgList?.pointee
        while prxCfg != nil {
            if let prxData = prxCfg?.data {
                let prxPointer = OpaquePointer(prxData)
                let domain = String(cString: linphone_proxy_config_get_domain(prxPointer))
                os_log("Domain in proxy config : %@", log: log_manager_debug, type: .debug, domain)
                linphone_core_remove_proxy_config(theLinphoneCore, prxPointer)
            }
            if (prxCfg?.next) != nil {
                prxCfg = prxCfg?.next.pointee
            } else {
                break
            }
        }
        
        // Get authenticate info list.
        let authInfoList = linphone_core_get_auth_info_list(theLinphoneCore)
        
        // Check auth info list and remove each one.
        var authInfo = authInfoList?.pointee
        while authInfo != nil {
            if let authData = authInfo?.data {
                let authPointer = OpaquePointer(authData)
                let username = String(cString: linphone_auth_info_get_username(authPointer))
                os_log("Username in authenticate info : %@", log: log_manager_debug, type: .debug, username)
                linphone_core_remove_auth_info(theLinphoneCore, authPointer)
            }
            if (authInfo?.next) != nil {
                authInfo = authInfo?.next.pointee
            } else {
                break
            }
        }
        
        os_log("=== After Remove Config & Account ===", log: log_manager_debug, type: .debug)
        os_log("Count proxy config list : %i", log: log_manager_debug, type: .debug, bctbx_list_size(linphone_core_get_proxy_config_list(theLinphoneCore)))
        os_log("Count authenticate info list : %i", log: log_manager_debug, type: .debug, bctbx_list_size(linphone_core_get_auth_info_list(theLinphoneCore)))
            
    }
    
    // MARK: - Calling
    /**
     Make a new call to an username.
     - parameters:
        - to: an username to send invite as string, Example - If full address is sip:John@testserver.com:5060 then [to] parameter should be John.
        - domain: a sip domain as string, Example - [domain] parameter should be testserver.com, Can be nil (it will get from register domain).
        - port: a port number as int, Can be nil (it will get from register port).
        - displayName: a display name as string, Can be nil (it will set to Sip-UA).
        - enableVideo: a video enabled status to send invite with video or audio only.
     */
    public func newOutgoingCall(to: String?, domain: String?, port: Int?, displayName: String?, enableVideo: Bool) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        SipCallManager.newOutgoingCall(to: to, domain: domain, port: port, displayName: displayName, enableVideo: enableVideo)
    }
    
    /**
     Update call duration.
     - parameters:
        - call: a specific call to get duration, Can be nil (it will get from the latest call).
     - returns: a call duration as string.
     */
    public func getCallDurationUpdate(call: OpaquePointer?) -> String {
        // Get call duration.
        var duration: Int = 0
        // If there is a specific call to get duration.
        if let aCall = call {
            // Check call state and call exist to prevent linphone library crash.
            if getStateOfCall(call: aCall) != LinphoneCallStateEnd &&
                getStateOfCall(call: aCall) != LinphoneCallStateError &&
                getStateOfCall(call: aCall) != LinphoneCallStateReleased &&
                checkCallExist(call: aCall) {
                duration = Int(linphone_call_get_duration(aCall))
            } else {
                return ""
            }
        // If there is no specific call to get duration, We will get the current call instead.
        } else {
            if let currentCall = getCurrentCall() {
                duration = Int(linphone_call_get_duration(currentCall))
            } else {
                if let latestCall = mCall {
                    // Check call state and call exist to prevent linphone library crash.
                    if getStateOfCall(call: latestCall) != LinphoneCallStateEnd &&
                        getStateOfCall(call: latestCall) != LinphoneCallStateError &&
                        getStateOfCall(call: latestCall) != LinphoneCallStateReleased &&
                        checkCallExist(call: latestCall) {
                        duration = Int(linphone_call_get_duration(latestCall))
                    } else {
                        return ""
                    }
                } else {
                    os_log("Latest call is nil : Can't calculate call duration", log: log_manager_error, type: .error)
                    return ""
                }
            }
        }
        // Convert duration to string.
        let stringTime = SipUtils.durationToString(duration: duration)
        os_log("Calling time : %@", log: log_manager_debug, type: .debug, stringTime)
        return stringTime
    }
    
    /**
     Get a call duration from specific call.
     - parameters:
        - call: a call to get duration.
     - returns: a call duration in seconds as int.
     */
    public func getCallDuration(call: OpaquePointer?) -> Int {
        // Get call duration.
        var duration: Int = 0
        // If there is a specific call to get duration.
        if let aCall = call {
            // Check call state and call exist to prevent linphone library crash.
            if getStateOfCall(call: aCall) != LinphoneCallStateEnd &&
                getStateOfCall(call: aCall) != LinphoneCallStateError &&
                getStateOfCall(call: aCall) != LinphoneCallStateReleased &&
                checkCallExist(call: aCall) {
                os_log("Get call duration from input call", log: log_manager_debug, type: .debug)
                duration = Int(linphone_call_get_duration(aCall))
            } else {
                os_log("Can't get call duration from input call", log: log_manager_error, type: .error)
                duration = 0
            }
            // If there is no specific call to get duration, We will get the current call instead.
        } else {
            if let currentCall = getCurrentCall() {
                os_log("Get call duration from current call", log: log_manager_debug, type: .debug)
                duration = Int(linphone_call_get_duration(currentCall))
            } else {
                if let latestCall = mCall {
                    // Check call state and call exist to prevent linphone library crash.
                    if getStateOfCall(call: latestCall) != LinphoneCallStateEnd &&
                        getStateOfCall(call: latestCall) != LinphoneCallStateError &&
                        getStateOfCall(call: latestCall) != LinphoneCallStateReleased &&
                        checkCallExist(call: latestCall) {
                        os_log("Get call duration from mCall", log: log_manager_debug, type: .debug)
                        duration = Int(linphone_call_get_duration(latestCall))
                    } else {
                        os_log("Can't get call duration from mCall", log: log_manager_error, type: .error)
                        duration = 0
                    }
                } else {
                    os_log("mCall is nil : Can't get call duration", log: log_manager_error, type: .error)
                    duration = 0
                }
            }
        }
        os_log("Call duration : %i", log: log_manager_debug, type: .debug, duration)
        return duration
    }
    
    /**
     Accept a call with audio or video if call state is LinphoneCallIncomingReceived or LinphoneCallIncomingEarlyMedia.
     - parameters:
        - call: a specific call to answer, Set to nil will use latest call instead.
        - withVideo:
     
            true, If accept call with video enabled.
     
            false, If accept call with audio.
     */
    public func answer(call: OpaquePointer?, withVideo: Bool) {
        if let aCall = call, checkCallExist(call: aCall) {
            os_log("Input call is not nil and call exist", log: log_manager_debug, type: .debug)
            let state = getStateOfCall(call: aCall)
            if state == LinphoneCallStateIncomingReceived || state == LinphoneCallStateIncomingEarlyMedia {
                os_log("Answer input call id : %@", log: log_manager_debug, type: .debug, getCallCallID(call: aCall))
                SipCallManager.answer(call: aCall, withVideo: withVideo)
            } else {
                os_log("Input call state is not incoming received", log: log_manager_debug, type: .debug)
                return
            }
        } else {
            os_log("Input call is nil, Use mCall(Latest call)", log: log_manager_debug, type: .debug)
            if let call = mCall, checkCallExist(call: call) {
                os_log("mCll is not nil and call exist", log: log_manager_debug, type: .debug)
                let state = getStateOfCall(call: call)
                if state == LinphoneCallStateIncomingReceived || state == LinphoneCallStateIncomingEarlyMedia {
                    os_log("Answer mCall id : %@", log: log_manager_debug, type: .debug, getCallCallID(call: call))
                    SipCallManager.answer(call: call, withVideo: withVideo)
                } else {
                    os_log("mCall state is not incoming received", log: log_manager_debug, type: .debug)
                    return
                }
            } else {
                os_log("mCall is nil : Can't answer", log: log_manager_error, type: .error)
                return
            }
        }
    }
    
    /**
     Decline a call.
     - parameters:
        - call: a specific call to decline, Set to nil will use latest call instead.
     */
    public func decline(call: OpaquePointer?) {
        if let aCall = call {
            os_log("Input call is not nil, Decline input call id : %@", log: log_manager_debug, type: .debug, getCallCallID(call: aCall))
            SipCallManager.decline(call: aCall)
        } else {
            os_log("Input call is nil, Use mCall(Latest call)", log: log_manager_debug, type: .debug)
            if let call = mCall {
                os_log("mCll is not nil, Decline mCall id : %@", log: log_manager_debug, type: .debug, getCallCallID(call: call))
                SipCallManager.decline(call: call)
            } else {
                os_log("mCall is nil : Can't decline", log: log_manager_error, type: .error)
                return
            }
        }
    }
    
    /**
     Hang up a call.
     - parameters:
        - call: a specific call to hangup, Set to nil will use latest call instead.
     */
    public func hangUp(call: OpaquePointer?) {
        if let aCall = call {
            os_log("Input call is not nil, Terminate input call id : %@", log: log_manager_debug, type: .debug, getCallCallID(call: aCall))
            // If a call is in conference, Terminate it.
            if (linphone_call_get_conference(aCall) != nil) {
                os_log("Found conference for input call, Terminate conference", log: log_manager_debug, type: .debug)
                terminateConference()
            }
            // Terminate call.
            terminateCall(call: aCall)
        } else {
            os_log("Input call is nil, Use mCall(Latest call)", log: log_manager_debug, type: .debug)
            if let call = mCall {
                os_log("mCll is not nil, Terminate mCall id : %@", log: log_manager_debug, type: .debug, getCallCallID(call: call))
                // If a call is in conference, Terminate it.
                if (linphone_call_get_conference(call) != nil) {
                    os_log("Found conference for mCall, Terminate conference", log: log_manager_debug, type: .debug)
                    terminateConference()
                }
                // Terminate call.
                terminateCall(call: call)
            } else {
                os_log("mCall is nil : Termiante all calls", log: log_manager_error, type: .error)
                terminateAllCalls()
            }
        }
    }
    
    /**
     Get a current call state.
     - returns: a LinphoneCallState.
     */
    public func getStateOfCurrentCall() -> LinphoneCallState {
        return SipCallManager.getStateOfCurrentCall()
    }
    
    /**
     Get a specific call state.
     - parameters:
        - call: a specific call to get state.
     - returns: a LinphoneCallState. Can be nil if linphone call is not exist.
     */
    public func getStateOfCall(call: OpaquePointer?) -> LinphoneCallState {
        return SipCallManager.getStateOfCall(call: call)
    }
    
    /**
     Check a local call with video or audio.
     - parameters:
        - call: a specific call to check local video.
     - returns:
     
        true, If a local call enable video.
     
        false, If a local call doesn't enable video.
     */
    public func isVideoEnabled(call: OpaquePointer) -> Bool {
        return SipVideoManager.isVideoEnabled(call: call)
        
    }
    
    /**
     Check a remote call with video or audio.
     - parameters:
        - call: a specific call to check remote video.
     - returns:
     
        true, If a remote call enable video.
     
        false, If a remote call doesn't enable video.
     */
    public func isRemoteVideoEnabled(call: OpaquePointer) -> Bool {
        return SipVideoManager.isRemoteVideoEnabled(call: call)
    }
    
    /**
     Get a current call, Can be nil if no running call.
     - returns: a current call.
     */
    public func getCurrentCall() -> OpaquePointer? {
        return SipCallManager.getCurrentCall()
    }
    
    /**
     Get a specific call id from call.
     - parameters:
        - call: a specific call to get ID.
     - returns: a call id as string.
     */
    public func getCallCallID(call: OpaquePointer?) -> String {
        return SipCallManager.getCallCallID(call: call)
    }
    
    /**
     Get all calls.
     - returns: an array of all calls.
     */
    public func getAllCalls() -> Array<OpaquePointer?> {
        return SipCallManager.getAllCalls()
    }
    
    /**
     Decline a call as busy reason, Can use to decline a pending incoming call.
     - parameters:
        - call: a specific call to decline as busy reason.
     */
    public func destroyAsBusyCall(call: OpaquePointer) {
        SipCallManager.destroyAsBusyCall(call: call)
    }
    
    /**
     Count a number of call.
     - returns: count all calls as int.
     */
    public func getCallsNumber() -> Int {
        return SipCallManager.getCallsNumber()
    }
    
    /**
     Get a call from call id.
     - parameters:
        - callID: a call id as string.
     - returns: a call.
     */
    public func getCallFromCallID(callID: String?) -> OpaquePointer? {
        return SipCallManager.getCallFromCallID(callID: callID)
    }
    
    /**
     Resume a specific call.
     - parameters:
        - call: a specific call to resume.
     */
    public func resumeCall(call: OpaquePointer) {
        SipCallManager.resumeCall(call: call)
    }
    
    /**
     Pause a specific call.
     - parameters:
        - call: a specific call to pause.
     */
    public func pauseCall(call: OpaquePointer) {
        SipCallManager.pauseCall(call: call)
    }
    
    /**
     Pause all calls.
     */
    public func pauseAllCalls() {
        SipCallManager.pauseAllCalls()
    }
    
    /**
     Terminate a specific call.
     - parameters:
        - call: a specific call to terminate.
     */
    public func terminateCall(call: OpaquePointer) {
        SipCallManager.terminateCall(call: call)
    }
    
    /**
     Terminate all calls.
     */
    public func terminateAllCalls() {
        SipCallManager.terminateAllCalls()
    }
    
    /**
     Transfer a call to a following username.
     - parameters:
        - call: a call that going to transfer.
        - username: an username to transfer, Example - If full address is sip:John@testserver.com:5060 then [username] parameter should be John.
     */
    public func transferCall(call: OpaquePointer, username: String?) {
        SipCallManager.transferCall(call: call, username: username)
    }
    
    /**
     Attended transfer call, Transfer a call to another running call.
     - parameters:
        - callToTransfer: a call that will be transfer in paused state.
        - destination: a destination call in running state.
     */
    public func transferToAnother(callToTransfer: OpaquePointer, destination: OpaquePointer) {
        SipCallManager.transferToAnother(callToTransfer: callToTransfer, destination: destination)
    }
    
    /**
     Add all calls into the conference.
     If no conference, a new internal conference context is created and all current calls are added to it.
     */
    public func addAllToConference() {
        SipCallManager.addAllToConference()
    }
    
    /**
     Join the local call to the running conference.
     */
    public func enterConference() {
        SipCallManager.enterConference()
    }
    
    /**
     Make the local call leave the running conference.
     */
    public func leaveConference() {
        SipCallManager.leaveConference()
    }
    
    /**
     Check the specific call is part of a conference or not.
     - parameters:
        - call: a specific call to check.
     - returns:
     
        true, If the call is part of a conference.
     
        false, If the call is not part of a conference.
     */
    public func isCallInConference(call: OpaquePointer) -> Bool {
        return SipCallManager.isCallInConference(call: call)
    }
    
    /**
     Check the local call is part of a conference or not.
     - returns:
     
        true, If the local call is part of a conference.
     
        false, If the local call is not part of a conference.
     */
    public func isInConference() -> Bool {
        return SipCallManager.isInConference()
    }
    
    /**
     Get the number of participant in the running conference.
     The local call is included in the count only if it is in the conference.
     - returns: a conference size as int.
     */
    public func getConferenceSize() -> Int {
        return SipCallManager.getConferenceSize()
    }
    
    /**
     Add a call to the conference.
     If no conference, A new internal conference context is created and the participant is added to it.
     - parameters:
        - call: a specific call to add in conference.
     */
    public func addCallToConference(call: OpaquePointer) {
        SipCallManager.addCallToConference(call: call)
    }
    
    /**
     Remove a call from the conference.
     If remove a remote call, The call becomes a normal call in paused state.
     If one single remote call is left alone together with the local call in conference after remove,
     The conference is automatically transformed into a simple call in [StreamsRunning] state.
     - parameters:
        - call: a specific call to remove from conference.
     */
    public func removeCallFromConference(call: OpaquePointer) {
        SipCallManager.removeCallFromConference(call: call)
    }
    
    /** Clear all calls from conference including local participant.
     */
    public func clearConference() {
        SipCallManager.clearConference()
    }
    
    /**
     Check the conference is created or not.
     - returns:
     
        true, If conference is created.
     
        false, If conference is not created.
     */
    public func isConferenceCreate() -> Bool {
        return SipCallManager.isConferenceCreate()
    }
    
    /**
     Terminate the running conference. If it is a local conference,
     All calls inside it will become back separate calls and will be put in [LinphoneCallPaused] state.
     If it is a conference involving a focus server, All calls inside the conference will be terminated.
     */
    public func terminateConference() {
        SipCallManager.terminateConference()
    }
    
    /**
     Switch between voice call and video call.
     - parameters:
        - videoStatus:
     
            true, To send re-invite only audio.
     
            false, To send re-invite audio and video.
     */
    public func disableVideo(videoStatus: Bool) {
        SipCallManager.disableVideo(videoStatus: videoStatus)
    }
    
    /**
     Update a current call when remote call re-invite with video or audio, Must call in [LinphoneCallUpdatedByRemote] call state.
     */
    public func acceptCallUpdate() {
        SipCallManager.acceptCallUpdate()
    }
    
    /**
     Lock a current call in call state LinphoneCallUpdatedByRemote, Must call in [LinphoneCallUpdatedByRemote] call state.
     - parameters:
        - call: a specific call to defer.
     */
    public func deferCall(call: OpaquePointer) {
        SipCallManager.deferCall(call: call)
    }
    
    /**
     Update a current call with video disable, Must call in [LinphoneCallUpdatedByRemote] call state.
     */
    public func refreshCall() {
        SipCallManager.refreshCall()
    }
    
    /**
     Get a call direction incoming or outgoing.
     - parameters:
        - call: a call to check direction.
     - returns: a linphone call direction.
     */
    public func getCallDirection(call: OpaquePointer) -> LinphoneCallDir {
        return SipCallManager.getCallDirection(call: call)
    }
    
    /**
     Get all missed call count.
     - returns: all missed call count as int.
     */
    public func getAllMissedCallCount() -> Int {
        return SipCallManager.getAllMissedCallCount()
    }
    
    /**
     Reset all missed call count.
     */
    public func resetAllMissedCallCount() {
        SipCallManager.resetAllMissedCallCount()
    }
    
    /** Count all outgoing init/progress/ringing/early media call.
     - returns: a number of outgoing call as int.
     */
    public func countOutgoingCall() -> Int {
        return SipCallManager.countOutgoingCall()
    }
    
    /** Count all incoming received/incoming early media call .
     - returns: a number of incoming call as int.
     */
    public func countIncomingCall() -> Int {
        return SipCallManager.countIncomingCall()
    }
    
    /** Count all running call.
     - returns: a number of running call as int.
     */
    public func countRunningCall() -> Int {
        return SipCallManager.countRunningCall()
    }
    
    /** Count all paused/pausing call.
     - returns: a number of paused/pausing call as int.
     */
    public func countPausedCall() -> Int {
        return SipCallManager.countPausedCall()
    }
    
    /** Count all paused by remote call.
     - returns: a number of paused by remote call as int.
     */
    public func countPausedByRemoteCall() -> Int {
        return SipCallManager.countPausedByRemoteCall()
    }
    
    /**
     Count the conference size but not include a local call.
     - returns: a conference size as int.
     */
    public func countConferenceCalls() -> Int {
        return SipCallManager.countConferenceCalls()
    }
    
    /**
     Get error reason from call.
     - parameters:
        - call: a call to get error.
     - returns: a call error reason.
     */
    public func getCallErrorReason(call: OpaquePointer) -> LinphoneReason {
        return SipCallManager.getCallErrorReason(call: call)
    }
    
    /**
     Get reason from call.
     - parameters:
        - call: a call to get reason.
     - returns: a call reason.
     */
    public func getCallReason(call: OpaquePointer) -> LinphoneReason {
        return SipCallManager.getCallReason(call: call)
    }
    
    /**
     Get a status of call.
     - parameters:
        - call: a call to get status.
     - returns:
        - a linphone call status.
     */
    public func getCallStatus(call: OpaquePointer) -> LinphoneCallStatus {
        return SipCallManager.getCallStatus(call: call)
    }
    
    /** Get call context.
     - returns: a call context structure.
     */
    public func getCallContext() -> CallContext {
       return callContext!
    }
    
    /**
    Set call context(A call to save before app go to background).
    - parameters:
        - call: a call to set in call context structure.
     */
    public func setCallContext(call: OpaquePointer?) {
        callContext!.call = call
        if call != nil {
            callContext!.isVideoEnabled = isVideoEnabled(call: call!)
        } else {
            callContext!.isVideoEnabled = false
        }
    }
    
    /**
     Remove a specific call history from address.
     - parameters:
        - address: a specific address to remove a call history. Can be nil it will get call history from identity address instead.
        - historyDetails: a specific sip call history to remove.
     */
    public func removeCallHistory(address: OpaquePointer?, historyDetails: SipCallHistoryDetails) {
        SipCallManager.removeCallHistory(address: address, historyDetails: historyDetails)
    }
    
    /**
     Remove all call history from address.
     - parameters:
        - address: a specific address to remove all call history. Can be nil it will get call history from identity address instead.
     */
    public func removeAllCallHistory(address: OpaquePointer?) {
        SipCallManager.removeAllCallHistory(address: address)
    }
    
    /**
     Get all call history from address.
     - parameters:
        - address: a specific address to get call history. Can be nil it will get call history from identity address instead.
     - returns: an array of SipCallHistoryDetails.
     */
    public func getAllCallHistory(address: OpaquePointer?) -> Array<SipCallHistoryDetails> {
        return SipCallManager.getAllCallHistory(address: address)
    }
    
    /**
     Reset all missed call count.
     */
    public func resetMissedCallCount() {
        SipCallManager.resetMissedCallCount()
    }
    
    // MARK: - Informations
    /**
     Using device default ringtone or using resource ringtone.
     - parameters:
        - use:
     
            true, To remove linphone ring sound path.
     
            false, To add linphone ring sound path.
     */
    public func enabledDeviceRingtone(use: Bool) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        if use {
            // Unwrap sound path.
            if let defaultRingSound = bundleFile(file: "default_ringtone.wav") {
                // Set default ringtone sound.
                os_log("Default ringtone sound path : %@", log: log_manager_debug, type: .debug, defaultRingSound)
                linphone_core_set_ring(theLinphoneCore, defaultRingSound.stringToUnsafePointerInt8())
            } else {
                os_log("Sound file does not exist", log: log_manager_error, type: .error)
                linphone_core_set_ring(theLinphoneCore, nil)
            }
        } else {
            // Unwrap sound path.
            if let customRingSound = bundleFile(file: "ringtone.wav") {
                // Set default ringtone sound.
                os_log("Custom ringtone sound path : %@", log: log_manager_debug, type: .debug, customRingSound)
                linphone_core_set_ring(theLinphoneCore, customRingSound.stringToUnsafePointerInt8())
            } else {
                os_log("Sound file does not exist", log: log_manager_error, type: .error)
                linphone_core_set_ring(theLinphoneCore, nil)
            }
        }
        let configSoundPath = lpConfigGetStringForKey(key: "local_ring", section: "sound", defaultValue: nil)
        os_log("Config sound path : %@", log: log_manager_debug, type: .debug, configSoundPath ?? "nil")
    }
    
    /**
     Get local identity from default proxy configuration.
     - returns: an identity as string.
     */
    public func getIdentityText() -> String {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return ""
        }
        return String(cString: linphone_core_get_identity(theLinphoneCore))
    }
    
    /**
     Get a remote address from call.
     - parameters:
        - call: a specific call to get remote address, Set to nil will use latest call instead.
     - returns: a linphone remote address (Use SipUtils.addressToString() or SipUtils.addressToStringNoDisplayName() to convert it to string).
     */
    public func getRemoteAddress(call: OpaquePointer?) -> OpaquePointer? {
        var remoteAddress: OpaquePointer?
        if let aCall = call {
            os_log("Input call is not nil, Get remote address from input call", log: log_manager_debug, type: .debug)
            remoteAddress = linphone_call_get_remote_address(aCall)
        } else {
             os_log("Input call is nil, Use mCall(Latest call)", log: log_manager_debug, type: .debug)
            if let call = mCall {
                os_log("mCll is not nil, Get remote address from mCall", log: log_manager_debug, type: .debug)
                remoteAddress = linphone_call_get_remote_address(call)
            } else {
                os_log("mCall is nil : Can't get remote address", log: log_manager_error, type: .error)
            }
        }
        os_log("Remote address : %@", log: log_manager_debug, type: .debug, remoteAddress != nil ? SipUtils.addressToString(address: remoteAddress!) : "nil")
        return remoteAddress
    }
    
    /**
     Get a remote user name from call.
     - parameters:
        - call: a specific call to get remote username string, Set to nil will use latest call instead.
     - returns: a remote user name as string.
     */
    public func getRemoteUsername(call: OpaquePointer?) -> String? {
        var remoteUsernameString: String?
        if let remoteAddress = getRemoteAddress(call: call) {
            if let remoteUsername = SipUtils.getUsernameFromAddress(address: remoteAddress) {
                remoteUsernameString = remoteUsername
            } else {
                os_log("Remote username is nil, Return nil", log: log_manager_debug, type: .debug)
            }
        } else {
            os_log("Remote addresse is nil, Can't get remote username", log: log_manager_error, type: .error)
        }
        os_log("Remote username : %@", log: log_manager_debug, type: .debug, remoteUsernameString ?? "nil")
        return remoteUsernameString
    }
    
    /**
     Get a remote display name from call.
     - parameters:
        - call: a specific call to get remote displayname string, Set to nil will use latest call instead.
     - returns: a remote display name as string.
     */
    public func getRemoteDisplayName(call: OpaquePointer?) -> String? {
        var remoteDisplaynameString: String?
        if let remoteAddress = getRemoteAddress(call: call) {
            if let remoteDisplayname = SipUtils.getDisplayNameFromAddress(address: remoteAddress) {
                remoteDisplaynameString = remoteDisplayname
            } else {
                os_log("Remote displayname is nil, Return nil", log: log_manager_debug, type: .debug)
            }
        } else {
            os_log("Remote addresse is nil, Can't get remote displayname", log: log_manager_error, type: .error)
        }
        os_log("Remote displayname : %@", log: log_manager_debug, type: .debug, remoteDisplaynameString ?? "nil")
        return remoteDisplaynameString
    }
    
    /**
     Set custom root CA path to a file or folder contain trusted root CAs (PEM format).
     - parameters:
        - rCA: a root ca path as string, Should use bundleFile() function to get a path.
     */
    public func setRootCA(rCA: String?) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        if let rootCA = rCA {
            linphone_core_set_root_ca(theLinphoneCore, rootCA.stringToUnsafePointerInt8())
        } else {
            os_log("Root CA path is nil", log: log_manager_error, type: .error)
            return
        }
    }
    
    /**
     Set custom ring sound and ringback sound path.
     - parameters:
        - ring: a ring sound path as string, Should use bundleFile() function to get a path.
        - ringBack: a ringback sound path as string, Should use bundleFile() function to get a path.
     */
    public func setRingAndRingBack(ring: String?, ringBack: String?) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        if let pathRing = ring {
            linphone_core_set_ring(theLinphoneCore, pathRing.stringToUnsafePointerInt8())
        } else {
            os_log("Ringtone sound path is nil", log: log_manager_error, type: .error)
            return
        }
        if let pathRingBack = ringBack {
            linphone_core_set_ringback(theLinphoneCore, pathRingBack.stringToUnsafePointerInt8())
        } else {
            os_log("Ringback sound path is nil", log: log_manager_error, type: .error)
            return
        }
    }
    
    /**
     Set custom pause sound path.
     - parameters:
        - pause: a pause sound path as string, Should use bundleFile() function to get a path.
     */
    public func setPauseSound(pause: String?) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        if let pathPause = pause {
            linphone_core_set_play_file(theLinphoneCore, pathPause.stringToUnsafePointerInt8())
        } else {
            os_log("Pause sound path is nil", log: log_manager_error, type: .error)
            return
        }
    }
    
    /**
     Set RTP encryption type manually.
     - parameters:
        - type: an encryption type as string.
     
            1. srtp
     
            2. zrtp
     
            3. dtls
     
            4. nil to set none encryption
     */
    public func enableRTPEncryptions(type: String?) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        let isSRTPSupport = Int(linphone_core_media_encryption_supported(theLinphoneCore, LinphoneMediaEncryptionSRTP)).boolValue
        let isZRTPSupport = Int(linphone_core_media_encryption_supported(theLinphoneCore, LinphoneMediaEncryptionZRTP)).boolValue
        let isDTLSSupport = Int(linphone_core_media_encryption_supported(theLinphoneCore, LinphoneMediaEncryptionDTLS)).boolValue
        os_log("SRTP support : %@", log: log_manager_debug, type: .debug, isSRTPSupport ? "true" : "false")
        os_log("ZRTP support : %@", log: log_manager_debug, type: .debug, isZRTPSupport ? "true" : "false")
        os_log("DTLS support : %@", log: log_manager_debug, type: .debug, isDTLSSupport ? "true" : "false")
        if let encryptType = type {
            if encryptType.lowercased() == "srtp" && isSRTPSupport {
                os_log("Set encryption type to SRTP", log: log_manager_debug, type: .debug)
                linphone_core_set_media_encryption(theLinphoneCore, LinphoneMediaEncryptionSRTP)
            } else if encryptType.lowercased() == "zrtp" && isZRTPSupport {
                os_log("Set encryption type to ZRTP", log: log_manager_debug, type: .debug)
                linphone_core_set_media_encryption(theLinphoneCore, LinphoneMediaEncryptionZRTP)
            } else if encryptType.lowercased() == "dtls" && isDTLSSupport {
                os_log("Set encryption type to DTLS", log: log_manager_debug, type: .debug)
                linphone_core_set_media_encryption(theLinphoneCore, LinphoneMediaEncryptionDTLS)
            } else {
                os_log("Set encryption type to None", log: log_manager_debug, type: .debug)
                linphone_core_set_media_encryption(theLinphoneCore, LinphoneMediaEncryptionNone)
            }
            
        } else {
            os_log("Encryption type is nil. Set encryption to none", log: log_manager_debug, type: .debug)
            linphone_core_set_media_encryption(theLinphoneCore, LinphoneMediaEncryptionNone)
        }
    }
    
    /**
     Check RTP encryption type manually.
     - returns: a encryption type as string.
     */
    public func getRTPEncryption() -> String {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return ""
        }
        return String(cString: linphone_media_encryption_to_string(linphone_core_get_media_encryption(theLinphoneCore)))
    }
    
    /**
     Enable or disable using ipv6.
     - parameters:
        - enabled:
     
            true, To use ipv6.
     
            false, To use ipv4 (default).
     */
    public func enableIpv6(enable: Bool) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_enable_ipv6(theLinphoneCore, UInt8(enable.intValue))
    }
    
    /**
     Check ipv6 is using or not.
     - returns:
     
        true, If ipv6 is enabled.
     
        false, If ipv6 is disabled.
     */
    public func isIpv6Enabled() -> Bool {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        return Int(linphone_core_ipv6_enabled(theLinphoneCore)).boolValue
    }
    
    /**
     Check a microphone is mute or unmute.
     - returns:
     
        true, If microphone is mute.
     
        false, If microphone is unmute.
     */
    public func isMicMute() -> Bool {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        let result = Int(linphone_core_mic_enabled(theLinphoneCore)).boolValue
        os_log("Microphone enable status : %@", log: log_manager_debug, type: .debug, result ? "true" : "false")
        return !result
    }
    
    /**
     Set mute or unmute microphone.
     - parameters:
        - status:
     
            true, To mute microphone.
     
            false, To unmute microphone.
     */
    public func muteMic(status: Bool) {
        let mute = !status
        linphone_core_enable_mic(theLinphoneCore, UInt8(mute.intValue))
        // Post microphone status.
        postMicrophoneNotification()
    }
    
    /* Post speaker status notification. */
    internal func postMicrophoneNotification() {
        let dictionaryMicrophone: [AnyHashable:Any] = ["enabled" : isMicMute()]

        // Post notification on main thread.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kMicrophoneStateUpdate, object: self, userInfo: dictionaryMicrophone)
        }
    }
    
    /**
     Get current device rotation.
     - returns: a degree of device rotation as int.
     */
    public func getDeviceRotation() -> Int {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return 0
        }
       return Int(linphone_core_get_device_rotation(theLinphoneCore))
    }
    
    /**
     Set current device rotation, This can be used by capture filters on mobile devices to select between portrait/landscape mode and to produce properly oriented images.
     - parameters:
        - rotation: a degree of device rotation as int.
     */
    public func setDeviceRotation(rotation: Int) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_set_device_rotation(theLinphoneCore, Int32(rotation))
        // Update call if video enable.
        if let currentCall = getCurrentCall() {
            if isVideoEnabled(call: currentCall) {
                SipCallManager.updateCall()
            }
        }
    }
    
    /**
     Check a call exist in linphone or not.
     - returns:
     
        true, If a call exist.
     
        false, If a call doesn't exist.
     */
    public func checkCallExist(call: OpaquePointer?) -> Bool {
        for aCall in getAllCalls() {
            if aCall == call {
                return true
            }
        }
        return false
    }
    
    /**
     Get a linphone default proxy config.
     - returns: a default proxy config.
     */
    public func getDefaultConfig() -> OpaquePointer? {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return nil
        }
        return linphone_core_get_default_proxy_config(theLinphoneCore)
    }
    
    /**
     Check a linphone default proxy config is enabled register or not.
     - returns:
     
        true, If there is default proxy config and it enable register.
     
        false, If there is no default proxy config or it doesn't enable register.
     */
    public func isDefaultConfigEnabledRegister() -> Bool {
        guard let defaultConfig = getDefaultConfig() else {
            os_log("Default proxy config is nil", log: log_manager_error, type: .error)
            return false
        }
        let enable = Int(linphone_proxy_config_register_enabled(defaultConfig)).boolValue
        os_log("Enable register for default proxy config : %@", log: log_manager_debug, type: .debug, enable ? "true" : "false")
        return enable
    }
    
    /**
     Check a specific linphone proxy config is enabled register or not.
     - returns:
     
        true, If a config enable register.
     
        false, If a config doesn't enable register.
     */
    public func isConfigEnabledRegister(config: OpaquePointer) -> Bool {
        let enable = Int(linphone_proxy_config_register_enabled(config)).boolValue
        os_log("Enable register for proxy config : %@", log: log_manager_debug, type: .debug, enable ? "true" : "false")
        return enable
    }
    
    /**
     Get all linphone proxy configs.
     - returns: all proxy configs as array.
     */
    public func getAllConfigs() -> Array<OpaquePointer?> {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return []
        }
        // Create new array.
        var prxCfgArray: Array<OpaquePointer?> = []
        // Get config list.
        let prxCfgList = linphone_core_get_proxy_config_list(theLinphoneCore)
        // Get pointer of config.
        var prxCfg = prxCfgList?.pointee
        // Loop pointer to get data and put in array.
        while prxCfg != nil {
            if let prxCfgData = prxCfg?.data {
                let prxCfgDataPt = OpaquePointer(prxCfgData)
                prxCfgArray.append(prxCfgDataPt)
            }
            if (prxCfg?.next) != nil {
                prxCfg = prxCfg?.next.pointee
            } else {
                break
            }
        }
        return prxCfgArray
    }
    
    /**
     Remove a specific proxy config and auth info.
     - parameters:
        - config: a linphone proxy config to remove.
     */
    public func removeConfigAndAuthInfo(config: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        // Remove proxy configs and auth infos.
        let identityAddr = linphone_proxy_config_get_identity_address(config)
        let username = linphone_address_get_username(identityAddr)
        let domain = linphone_address_get_domain(identityAddr)
        os_log("Delete proxy config and auth info for username : %@", log: log_manager_debug, type: .debug, String(cString: username!))
        if let authInfo = linphone_core_find_auth_info(theLinphoneCore, domain, username, domain) {
            linphone_core_remove_auth_info(theLinphoneCore, authInfo)
        } else {
            os_log("Not found auth info for username : %@", log: log_manager_debug, type: .debug, String(cString: username!))
        }
        linphone_core_remove_proxy_config(theLinphoneCore, config)
    }
    
    /**
     Clear all proxy configs and all auth infos.
     */
    public func clearAllConfigsAndAuthInfos() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        // Remove all proxy configs and auth infos.
        os_log("Clear proxy config and auth info", log: log_manager_debug, type: .debug)
        linphone_core_clear_proxy_config(theLinphoneCore)
        linphone_core_clear_all_auth_info(theLinphoneCore)
    }
    
    /**
     Get an auth info from proxy config.
     - parameters:
        - config: a linphone proxy config to get auth info.
     - returns: a linphone auth info.
     */
    public func getAuthInfoFromConfig(config: OpaquePointer) -> OpaquePointer? {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return nil
        }
        let identityAddr = linphone_proxy_config_get_identity_address(config)
        let username = linphone_address_get_username(identityAddr)
        let domain = linphone_address_get_domain(identityAddr)
        os_log("Find auth info from config using identity address", log: log_manager_debug, type: .debug)
        return linphone_core_find_auth_info(theLinphoneCore, domain, username, domain)
    }
    
    /**
     Get all auth infos.
     - returns: all auth infos as array.
     */
    public func getAllAuthInfos() -> Array<OpaquePointer?> {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return []
        }
        // Create new array.
        var authInfoArray: Array<OpaquePointer?> = []
        // Get auth info list.
        let authInfoList = linphone_core_get_auth_info_list(theLinphoneCore)
        // Get pointer of auth info.
        var authInfo = authInfoList?.pointee
        // Loop pointer to get data and put in array.
        while authInfo != nil {
            if let authInfoData = authInfo?.data {
                let authInfoDataPt = OpaquePointer(authInfoData)
                authInfoArray.append(authInfoDataPt)
            }
            if (authInfo?.next) != nil {
                authInfo = authInfo?.next.pointee
            } else {
                break
            }
        }
        return authInfoArray
    }
    
    /**
     Check a proxy config exist in linphone or not.
     - parameters:
        - username: a username as atring.
        - domain: a domain as string.
        - port: a port as int.
     - returns: a linhone proxy config if found.
     */
    public func checkConfigExist(username: String, domain: String, port: Int) -> OpaquePointer? {
        if getAllConfigs().count != 0 {
            os_log("Found saved config, Start checking", log: log_manager_debug, type: .debug)
            os_log("===== Input config =====", log: log_manager_debug, type: .debug)
            os_log("Username : %@ | Domain : %@ | Port : %i", log: log_manager_debug, type: .debug, username, domain, port)
            var tmpCfg: OpaquePointer?
            os_log("===== Saved config =====", log: log_manager_debug, type: .debug)
            for config in getAllConfigs() {
                let cfgUsername = SipUtils.getIdentityUsernameFromConfig(config: config!)
                let cfgDomain = SipUtils.getIdentityDomainFromConfig(config: config!)
                let cfgPort = SipUtils.getIdentityPortFromConfig(config: config!)
                os_log("Username : %@ | Domain : %@ | Port : %i", log: log_manager_debug, type: .debug, cfgUsername ?? "", cfgDomain ?? "", cfgPort ?? 0)
                if (username == cfgUsername) && (domain == cfgDomain) && (port == cfgPort) {
                    os_log("Match proxy config!", log: log_manager_debug, type: .debug)
                    tmpCfg = config
                } else {
                    os_log("Not match proxy config!", log: log_manager_debug, type: .debug)
                }
            }
            return tmpCfg
        } else {
            os_log("No saved config, Skip checking", log: log_manager_debug, type: .debug)
            return nil
        }
    }
    
    /**
     Check a proxy config exist in linphone or not.
     - parameters:
        - config: a linphone proxy config.
     - returns:
     
        true, If a config exist.
     
        false, If a config doesn't exist.
     */
    public func checkConfigExist(config: OpaquePointer) -> Bool {
        for config in getAllConfigs() {
            if config == config {
                return true
            }
        }
        return false
    }
    
    /**
     Use a specific proxy config to enable register, Enable push notification and set as default, Will disable register and push notification others proxy config.
     - parameters:
        - config: a proxy config to process.
     */
    public func enableRegister(config: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        if !checkConfigExist(config: config) {
            os_log("Proxy config doesn't exist", log: log_manager_error, type: .error)
            return
        }
        os_log("Set default proxy config, enable register and enable push notification to user : %@", log: log_manager_debug, type: .debug, SipUtils.getIdentityUsernameFromConfig(config: config)!)
        // Set proxy config as a default proxy config.
        linphone_core_set_default_proxy_config(theLinphoneCore, config)
        // Set config expire time
        linphone_proxy_config_set_expires(config, 3600)
        // Enable register.
        linphone_proxy_config_enable_register(config, UInt8(true.intValue))
        // Turn on push notification for default proxy config.
        enablePushNotification(enable: true)
        // Set token to default proxy config.
        configurePushTokenForProxyConfig(proxyConfig: config)
        
        for anotherConfig in getAllConfigs() where anotherConfig != config {
            os_log("Disable register and push notification to user : %@", log: log_manager_debug, type: .debug, SipUtils.getIdentityUsernameFromConfig(config: anotherConfig!)!)
            // Set config expire time
            linphone_proxy_config_set_expires(anotherConfig, 0)
            // Force refresh register to unregister from server
            linphone_proxy_config_refresh_register(anotherConfig)
            // Disable register.
            linphone_proxy_config_enable_register(anotherConfig, UInt8(false.intValue))
            // Disable push notification.
            enablePushNotification(config: anotherConfig!, enable: false)
        }
        // Refresh register once.
        refreshRegister()
    }
    
    /**
     Use a specific proxy config to unregister, Disable push notification but set as default.
     - parameters:
        - config: a proxy config to process.
     */
    public func unregister(config: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        if !checkConfigExist(config: config) {
            os_log("Proxy config doesn't exist", log: log_manager_error, type: .error)
            return
        }
        os_log("Set default proxy config, unregister and disable push notification to user : %@", log: log_manager_debug, type: .debug, SipUtils.getIdentityUsernameFromConfig(config: config)!)
        // Set proxy config as a default proxy config.
        linphone_core_set_default_proxy_config(theLinphoneCore, config)
        // Set config expire time
        linphone_proxy_config_set_expires(config, 0)
        // Disable register.
        linphone_proxy_config_enable_register(config, UInt8(false.intValue))
        // Turn off push notification for default proxy config.
        enablePushNotification(enable: false)
        // Unset token to default proxy config.
        configurePushTokenForProxyConfig(proxyConfig: config)
        // Refresh register once.
        refreshRegister()
    }
    
    // MARK: - Checking
    /* Check a device is not iPhone3G */
    fileprivate func isNotIphone3G() -> Bool {
        
        var result: Bool
        let size = size_t()
        let sizePt = UnsafeMutablePointer<Int>(bitPattern: size)
        sysctlbyname("hw.machine", nil, sizePt, nil, 0)
        let machine = malloc(size)
        sysctlbyname("hw.machine", machine, sizePt, nil, 0)
        let platform = String(cString: (machine?.assumingMemoryBound(to: Int8.self))!)
        free(machine)
        
        result = !(platform == "iPhone1,2")
        return result
    }
    
    // MARK: - Vibration (It might cause an AppStore reject the application)
    /**
     Start vibration with timer.
     - parameters:
        - sleepTime: a frequency of vibration.
     */
    public func startVibration(sleepTime: Double) {
        if vibrateTimer == nil {
            vibrateTimer = Timer.scheduledTimer(timeInterval: sleepTime, target: self, selector: #selector(vibrate), userInfo: nil, repeats: true)
        }
    }
    
    /**
     Stop vibration.
     */
    public func stopVibration() {
        if vibrateTimer != nil {
            vibrateTimer?.invalidate()
            vibrateTimer = nil
        }
    }
    
    /* Vibration */
    @objc private func vibrate() {
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    // MARK: - Network connection
    /* Prepare network reachability */
    fileprivate func setupNetworkReachabilityCallback() {
        
        // Initialize network reachability contex.
        var context = SCNetworkReachabilityContext()
        // Initialize the socket IPV4 address struct.
        var zeroAddress = sockaddr_in()
        
        // bzero(char *s, int n) use for copying n bytes, each with a value of zero, into string s.
        // For initialize sockaddr_in with 0 in memory before using.
        bzero(&zeroAddress, MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        // Remove runloop for old network reachability.
        if proxyReachability != nil {
            os_log("Canceling old network reachability", log: log_manager_debug, type: .debug)
            SCNetworkReachabilityUnscheduleFromRunLoop(proxyReachability!, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            proxyReachability = nil
        }
        
        // This notification is used to detect SSID change (switch between wifi network).
        // The ReachabilityCallback is not triggered when switching between 2 private wifi.
        // Since we can't be sure we were already observer, remove observer and add it again each time to be improved.
        SSID = SipNetworkManager.getCurrentWifiSSID()
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), bridgeRetained(obj: self), CFNotificationName("com.apple.system.config.network_change" as CFString), nil)
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), bridgeRetained(obj: self),
                                        NetworkReachabilityNotification, ("com.apple.system.config.network_change" as CFString),
                                        nil, CFNotificationSuspensionBehavior.deliverImmediately)
        
        // Cast sockaddr_in to sockaddr.
        var localSockAddress = zeroAddress
        var sockAddress = withUnsafePointer(to: &localSockAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout.size(ofValue: zeroAddress), {
                $0.pointee
            })
        })
        os_log("Sock Address : %@", log: log_manager_debug, type: .debug, String(describing: sockAddress))
        
        // Create network reachability.
        proxyReachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, &sockAddress)

        // Set network reachability callback.
        if !SCNetworkReachabilitySetCallback(proxyReachability!, NetworkReachabilityCb, &context) {
            os_log("Can't register reachability callback : %@", log: log_manager_error, type: .error, SCErrorString(SCError()))
            return
        }
        
        // Set runloop to network reachability.
        if !SCNetworkReachabilityScheduleWithRunLoop(proxyReachability!, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
            os_log("Can't register schedule reachability callback : %@", log: log_manager_error, type: .error, SCErrorString(SCError()))
            return
        }
        
        // Check network connectivity now without waiting for a change.
        var flags = SCNetworkReachabilityFlags()
        if SCNetworkReachabilityGetFlags(proxyReachability!, &flags) {
            NetworkReachabilityCb(proxyReachability!, flags, nil)
        }
        
    }
    
    /**
     Refresh network reachability.
     */
    public func refreshNetworkReachability() {
        setupNetworkReachabilityCallback()
    }
    
    /**
     Force reset network connectivity.
     */
    public func resetConnectivity() {
        connectivity = Connectivity.none
        setupNetworkReachabilityCallback()
    }
    
    /**
     Set network reachability to library.
     - parameters:
        - reachable:
     
            true, To let library initiate a register process to all proxy.
     
            false, To disable a automatic network detection mode.
     */
    public func setNetworkReachable(reachable: Bool) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_set_network_reachable(theLinphoneCore, UInt8(reachable.intValue))
    }
    
    /**
     Check a network is reachable or not.
     - returns:
     
        - true, If network is reachable.
     
        - false, If network is not reachable.
     */
    public func isNetworkReachable() -> Bool {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        return Int(linphone_core_is_network_reachable(theLinphoneCore)).boolValue
    }
    
    /* Get IP Address from domain name */
    fileprivate func getIPAddressFromDomain() -> String? {
        guard convertDomain != nil else {
            os_log("Convert domain is nil", log: log_manager_error, type: .error)
            return nil
        }
        // Get IP address from domain address
        let host = CFHostCreateWithName(nil, convertDomain! as CFString).takeRetainedValue()
        CFHostStartInfoResolution(host, .addresses, nil)
        var success: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
            let theAddress = addresses.firstObject as? NSData {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                           &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                return String(cString: hostname)
            }
        }
        return nil
    }
    
    /* Opening Stream to send string to domain to check realtime connection */
    fileprivate func kickOffNetworkConnection() {
        
        os_log("Check realtime connection", log: log_manager_debug, type: .debug)
        // Get ip address from domain to test connection.
        let ipAddr: String?
        if let hostIPAddr = getIPAddressFromDomain() {
            os_log("IP Address is : %@", log: log_manager_debug, type: .debug, hostIPAddr)
            ipAddr = hostIPAddr
        } else {
            os_log("IP address is nil", log: log_manager_error, type: .error)
            return
        }
        
        var in_progress: Bool = false
        // To prevent calling function again.
        if in_progress {
            os_log("Connection kickoff already in progress", log: log_manager_debug, type: .debug)
            return
        }
        
        in_progress = true
        // Dispatch a queue that shared by a whole system.
        DispatchQueue.global().async {
            let sleep_us: Int = 10000
            let timeout_s: Int = 5
            var timeout_reached: Bool = false
            var loop: Int = 0
            var writeStream: Unmanaged<CFWriteStream>?
            
            // Create readable and writeable stream connect to tcp/ip port of a particular host.
            CFStreamCreatePairWithSocketToHost(nil, ipAddr! as CFString, 15000, nil, &writeStream)
            // Open a stream.
            let res: Bool = CFWriteStreamOpen(writeStream?.takeUnretainedValue())
            let buff: String = "hello"
            // Store a system values, Get the current time.
            let start: time_t = time(nil)
            var loop_time: time_t
            
            // If open stream fail then quit function.
            if !res {
                os_log("Can not open write stream, Backing off", log: log_manager_error, type: .error)
                writeStream?.release()
                in_progress = false
                return
            }
            
            // Check open stream status result.
            var status: CFStreamStatus = CFWriteStreamGetStatus(writeStream?.takeUnretainedValue())
            // Loop to wait open stream status result if the result is error.
            while ((status != CFStreamStatus.open) && (status != CFStreamStatus.error)) {
                // Sleep 10 seconds.
                usleep(UInt32(sleep_us))
                // Refresh get open stream status result.
                status = CFWriteStreamGetStatus(writeStream?.takeUnretainedValue())
                // Get current time.
                loop_time = time(nil)
                // If time in loop - start time then equal/morethan timeout.
                // Stop while loop.
                if (loop_time - start) >= timeout_s {
                    timeout_reached = true
                    break
                }
                loop += 1
            }
            // If stream is open.
            if (status == CFStreamStatus.open) {
                let buffPt = buff.stringToUnsafePointerInt8()
                let buffPt2 = buff.stringToUnsafePointerUInt8()
                // Write data to a writable stream.
                CFWriteStreamWrite(writeStream?.takeUnretainedValue(), buffPt2, strlen(buffPt))
            // If stream is not open and timeout is not reached.
            } else if (!timeout_reached) {
                // Get the error with the stream.
                let error: CFError = CFWriteStreamCopyError(writeStream?.takeUnretainedValue())
                os_log("CFStreamError: %@", log: log_manager_error, type: .error, error as! CVarArg)
            // If stream is not open and timeout is reached.
            } else if (timeout_reached) {
                os_log("CFStream timeout reached", log: log_manager_error, type: .error)
            }
            // Close a writable stream.
            CFWriteStreamClose(writeStream?.takeUnretainedValue())
            in_progress = false
        }
        
    }
    
    // MARK: - Global notification
    @objc func globalStateChangedNotificationHandler(notification: Notification) {
        if  notification.userInfo!["state"] as! LinphoneGlobalState  == LinphoneGlobalOn {
            finishCoreConfiguration()
        }
    }
    fileprivate func onGlobalStateChanged(state: LinphoneGlobalState, message: UnsafePointer<Int8>?) {
        
        let globalState = String(cString: linphone_global_state_to_string(state))
        os_log("Global State Change : %@ (message: %@)", log: log_manager_debug, type: .debug, globalState, (message != nil ? String(cString: message!) : "nil"))
        let dictionary: [AnyHashable:Any] = ["state" : state , "message" : message ?? ""]
        
        // Post notification on main thread.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kLinphoneGlobalStateUpdate, object: self, userInfo: dictionary)
        }
        
    }
    
    // MARK: - Configuring notification
    @objc func configuringStateChangedNotificationHandler(notification: Notification) {
        
        if notification.userInfo!["state"] as! LinphoneConfiguringState == LinphoneConfiguringSuccessful {
            if let proxyCfg = linphone_core_get_default_proxy_config(theLinphoneCore) {
                configurePushTokenForProxyConfig(proxyConfig: proxyCfg)
            }
        }
        
    }
    fileprivate func onConfiguringStateChanged(state: LinphoneConfiguringState, message: UnsafePointer<Int8>?) {
        
        let configState =  String(cString: linphone_configuring_state_to_string(state))
        os_log("Configuring State Change : %@ (message: %@)", log: log_manager_debug, type: .debug, configState, (message != nil ? String(cString: message!) : "nil"))
        let dictionary: [AnyHashable:Any] = ["state" : state , "message" : message ?? ""]
        
        // Post notification on main thread.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kLinphoneConfiguringStateUpdate, object: self, userInfo: dictionary)
        }
        
    }
    
    // MARK: - Register notification
    @objc func registerStateChangedNotificationHandler(notification: Notification) {
        
        let cfg = notification.userInfo!["cfg"] as! OpaquePointer
        let registerStateConfig = String(cString: linphone_registration_state_to_string(linphone_proxy_config_get_state(cfg)))
        os_log("Register state from config : %@", log: log_manager_debug, type: .debug, registerStateConfig)
        
        let registerState = notification.userInfo!["state"] as! LinphoneRegistrationState
        let registerStateString = String(cString: linphone_registration_state_to_string(registerState))
        os_log("Register state from notification : %@", log: log_manager_debug, type: .debug, registerStateString)
        
        let registerMessage = String(cString: notification.userInfo!["message"] as! UnsafePointer<Int8>)
        os_log("Register message : %@", log: log_manager_debug, type: .debug, registerMessage)
        
        let registerError = notification.userInfo!["errorMessage"] as! String
        os_log("Register error message : %@", log: log_manager_debug, type: .debug, registerError)
        
        switch registerState {
        case LinphoneRegistrationNone:
            os_log("Not registered", log: log_manager_debug, type: .debug)
            registerStatus = "Not registered"
        case LinphoneRegistrationProgress:
            os_log("Registration in progress", log: log_manager_debug, type: .debug)
            registerStatus = "Registration in progress"
        case LinphoneRegistrationOk:
            os_log("Registered", log: log_manager_debug, type: .debug)
            registerStatus = "Registered"
        case LinphoneRegistrationCleared:
            os_log("Registration cleared", log: log_manager_debug, type: .debug)
            registerStatus = "Registration cleared"
        case LinphoneRegistrationFailed:
            os_log("Registration failed", log: log_manager_debug, type: .debug)
            registerStatus = "Registration failed"
        default:
            os_log("Not connected", log: log_manager_debug, type: .debug)
            registerStatus = "Not connected"
        }
        
    }
    fileprivate func onRegisterationStateChanged(cfg: OpaquePointer?, state: LinphoneRegistrationState, message: UnsafePointer<Int8>?) {
        
        // Convert register state to string using linphone function.
        let regisState = String(cString: linphone_registration_state_to_string(state))
        os_log("Registration State Change : %@ (message: %@)", log: log_manager_debug, type: .default, regisState, (message != nil ? String(cString: message!) : "nil"))
        
        // Get error register reason.
        let reason = linphone_proxy_config_get_error(cfg);
        let errorMessage = String(cString: linphone_reason_to_string(reason))
        
        let dictionary: [AnyHashable:Any] = ["state" : state , "cfg" : cfg ?? "" , "message" : message ?? "" , "errorMessage" : errorMessage]
        
        // Post notification on main thread.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kLinphoneRegistrationStateUpdate, object: self, userInfo: dictionary)
        }
        
    }
    
    // MARK: - Calling notification
    private func onCallStateChanged(call: OpaquePointer?, state: LinphoneCallState, message: UnsafePointer<Int8>?) {
        
        os_log("Call state is : %@", log: log_manager_debug, type: .debug, String(cString: linphone_call_state_to_string(state)) )
        os_log("Local video enabled status : %@", log: log_manager_debug, type: .debug, isVideoEnabled(call: call!) ? "true" : "false" )
        
        // Update all input status.
        SipAudioManager.connectedStatus()
        
        // Update a changed call.
        mCall = call
        os_log("mCall id update : %@ | %@", log: log_manager_debug, type: .debug, getRemoteUsername(call: mCall) ?? "nil", getCallCallID(call: mCall))
        
        // See all calls.
        os_log("==== All calls ====", log: log_manager_debug, type: .debug)
        for call in getAllCalls() {
            os_log("Display Name : %@", log: log_manager_debug, type: .debug, getRemoteDisplayName(call: call) ?? "-")
            os_log("Username : %@", log: log_manager_debug, type: .debug, getRemoteUsername(call: call)!)
            os_log("Call id : %@", log: log_manager_debug, type: .debug, getCallCallID(call: call))
            os_log("Call state : %@", log: log_manager_debug, type: .debug, SipUtils.callStateToString(callState: getStateOfCall(call: call)))
        }
        os_log("===================", log: log_manager_debug, type: .debug)
        
        // Check call id in push calls to stop push lone running background task for notifying missed call.
        if getCallCallID(call: call) != "" {
            let callID = getCallCallID(call: call)
            for (index,id) in pushCalls!.enumerated() where id == callID {
                os_log("Delete push call [%@] in array success, Don't need background task to notify missed call", log: log_manager_debug, type: .debug, id)
                pushCalls!.remove(at: index)
            }
            // Check another push call id for needed background task.
            var needBGTask = false
            if pushCalls!.count != 0 {
                os_log("Still need background task to notify missed call", log: log_manager_debug, type: .debug)
                needBGTask = true
            }
            if pushCallBGTask != .invalid && !needBGTask {
                os_log("Push calls clear, Stop call background task", log: log_manager_debug, type: .debug)
                UIApplication.shared.endBackgroundTask(pushCallBGTask)
                pushCallBGTask = .invalid
                pushCalls! = []
            }
            os_log("Push calls array : %@", log: log_manager_debug, type: .debug, pushCalls ?? "")
        } else {
            os_log("Can't get call id, Can't check push calls array to stop missed call background task", log: log_manager_error, type: .error)
        }
        
        if state == LinphoneCallStateOutgoingInit {
            os_log("Outgoing call init...", log: log_manager_debug, type: .debug)
            
            if !useCallKit || Platform.isSimulator {
                os_log("Not using CallKit : Let SipUA handle audio route and proximity", log: log_manager_debug, type: .debug)
                // Start proximity sensor.
                device.isProximityMonitoringEnabled = true
                // Set audio to default mode.
                setAudioManagerInDefaultMode()
                // Default route audio to available device.
                if isBluetoothConnected() {
                    routeAudioToBluetooth()
                } else if isHeadphonesConnected() {
                    routeAudioToHeadphones()
                } else {
                    routeAudioToReceiver()
                }
            } else {
                os_log("Using CallKit : Let CallKit handle audio route and proximity", log: log_manager_debug, type: .debug)
                os_log("Proximity status : %@", log: log_manager_debug, type: .debug, device.isProximityMonitoringEnabled ? "enable" : "disable")
            }
        
        }
        
        if state == LinphoneCallStateIncomingReceived && call != getCurrentCall() {
            os_log("Incoming call received condition [Current Call != Incoming Call]", log: log_manager_debug, type: .debug)
            os_log("Current call id : %@", log: log_manager_debug, type: .debug, getCallCallID(call: getCurrentCall()))
            os_log("Another incoming call id : %@", log: log_manager_debug, type: .debug, getCallCallID(call: call))
            updateMCall(txtLog: "after incoming received and call is not a current call")
        }
        
        else if state == LinphoneCallStateIncomingReceived || state == LinphoneCallStateIncomingEarlyMedia {
            os_log("Incoming call received/early media...", log: log_manager_debug, type: .debug)
            
            if !useCallKit || Platform.isSimulator {
                os_log("Not using CallKit : Let SipUA handle audio route and proximity", log: log_manager_debug, type: .debug)
                // Set audio to default mode.
                setAudioManagerInDefaultMode()
                // Route audio to speaker.
                routeAudioToSpeaker()
                // Start proximity sensor.
                device.isProximityMonitoringEnabled = true
            } else {
                os_log("Using CallKit : Let CallKit handle audio route and proximity", log: log_manager_debug, type: .debug)
                os_log("Proximity status : %@", log: log_manager_debug, type: .debug, device.isProximityMonitoringEnabled ? "enable" : "disable")
            }
            
        }
        
        if state == LinphoneCallStateConnected {
            os_log("Call Connected...", log: log_manager_debug, type: .debug)
            
            if !useCallKit || Platform.isSimulator {
                os_log("Not using CallKit : Let SipUA handle audio route", log: log_manager_debug, type: .debug)
                // Default route audio to available device.
                if isBluetoothConnected() {
                    routeAudioToBluetooth()
                } else if isHeadphonesConnected() {
                    routeAudioToHeadphones()
                } else {
                    routeAudioToReceiver()
                }
            } else {
                os_log("Using CallKit : Let CallKit handle audio route", log: log_manager_debug, type: .debug)
            }
            
        }
        
        if state == LinphoneCallStateStreamsRunning {
            os_log("Streams running...", log: log_manager_debug, type: .debug)
            
            if !useCallKit || Platform.isSimulator {
                os_log("Not using CallKit : Let SipUA handle audio route and proximity and sleep mode", log: log_manager_debug, type: .debug)
                // Prevent device to sleep.
                turnOffSleepMode()
                // Route audio to available device.
                if isBluetoothConnected() {
                    routeAudioToBluetooth()
                } else if isHeadphonesConnected() {
                    routeAudioToHeadphones()
                } else {
                    // In video call.
                    if isVideoEnabled(call: call!) {
                        // Stop proximity sensor.
                        device.isProximityMonitoringEnabled = false
                        // Set audio to default mode.
                        setAudioManagerInDefaultMode()
                        // Route to speaker.
                        routeAudioToSpeaker()
                    // In voice call.
                    } else {
                        // Start proximity sensor.
                        device.isProximityMonitoringEnabled = true
                        // Set audio to voice mode.
                        setAudioManagerInVoiceCallMode()
                        // Route to receiver.
                        routeAudioToReceiver()
                    }
                }
            } else {
                os_log("Using CallKit : Let CallKit handle audio route and proximity", log: log_manager_debug, type: .debug)
                os_log("Proximity status : %@", log: log_manager_debug, type: .debug, device.isProximityMonitoringEnabled ? "enable" : "disable")
            }
            
        }
 
        if state == LinphoneCallStatePausing || state == LinphoneCallStatePaused || state == LinphoneCallStatePausedByRemote {
            os_log("Call Pausing/Paused/PausedByRemote...", log: log_manager_debug, type: .debug)
            
            // Update mCall to running call if found.
            updateMCall(txtLog: "after pausing/paused/paused by remote")
            
        }
        
        if state == LinphoneCallStateEnd || state == LinphoneCallStateError {
            os_log("Call End/Error...", log: log_manager_debug, type: .debug)
            
            // Update mCall to a call remain, In case more than 1 call because mCall will use in [Informations] group and others.
            // Some case we can't use current call because if all calls paused current call will be nil.
            updateMCall(txtLog: "after end/error")
            
            // Prevent audio route change if call has more than 1.
            // If another call is hangup but a paused call still stay.
            if getCallsNumber() == 0 {
                if !useCallKit || Platform.isSimulator {
                    os_log("Not using CallKit : Let SipUA handle audio route", log: log_manager_debug, type: .debug)
                    // Default route audio to available device.
                    if isBluetoothConnected() {
                        routeAudioToBluetooth()
                    } else if isHeadphonesConnected() {
                        routeAudioToHeadphones()
                    } else {
                        routeAudioToReceiver()
                    }
                } else {
                    os_log("Using CallKit : Let CallKit handle audio route", log: log_manager_debug, type: .debug)
                }
                
            } else {
                os_log("There is some call remain : Skip audio route change", log: log_manager_debug, type: .debug)
            }
            
        }
        
        if state == LinphoneCallStateReleased {
            os_log("Call Released...", log: log_manager_debug, type: .debug)
            
            // Update mCall to a call remain, In case more than 1 call because mCall will use in [Informations] group and others.
            // Some case we can't use current call because if all calls paused current call will be nil.
            updateMCall(txtLog: "after release")
            
            // Prevent audio route change if call has more than 1.
            // If another call is hangup but a paused call still remain.
            if getCallsNumber() == 0 {
                if !useCallKit || Platform.isSimulator {
                    os_log("Not using CallKit : Let SipUA handle audio route and proximity and sleep mode", log: log_manager_debug, type: .debug)
                    // Let device can sleep.
                    turnOnSleepMode()
                    // Set audio to default mode.
                    setAudioManagerInDefaultMode()
                    // Restart audio session.
                    restartAudioSession()
                    // Stop proximity sensor.
                    device.isProximityMonitoringEnabled = false
                } else {
                    os_log("Using CallKit : Let CallKit handle audio route and proximity", log: log_manager_debug, type: .debug)
                    os_log("Proximity status : %@", log: log_manager_debug, type: .debug, device.isProximityMonitoringEnabled ? "enable" : "disable")
                }
            } else {
                os_log("There is some call remain : Skip audio route change", log: log_manager_debug, type: .debug)
            }
            
        }
        
        let dictionary: [AnyHashable:Any] = ["call" : call ?? "", "mCall" : mCall ?? "" , "state" : state , "message" : (message != nil ? String(cString: message!) : "") ]
        
        // Post notification on main thread.
        NotificationCenter.default.post(name: .kLinphoneCallStateUpdate, object: self, userInfo: dictionary)
        
    }
    /* Update call property(mCall) to the latest call */
    private func updateMCall(txtLog: String) {
        if getCallsNumber() != 0 {
            // Find running call.
            var countRunningCall = 0
            for call in getAllCalls() where getStateOfCall(call: call) == LinphoneCallStateStreamsRunning {
                mCall = call
                countRunningCall += 1
            }
            
            // If no running call. Check incoming call if any.
            var countIncomingCall = 0
            for call in getAllCalls() where getStateOfCall(call: call) == LinphoneCallStateIncomingReceived {
                mCall = call
                countIncomingCall += 1
            }
            
            // If no running call and no incoming call. Update mCall to latest call.
            if countRunningCall == 0 && countIncomingCall == 0 {
                mCall = getAllCalls().last!
            }
            os_log("mCall id update %@ : UserName [%@] | Call id [%@]", log: log_manager_debug, type: .debug, txtLog, getRemoteUsername(call: mCall)!, getCallCallID(call: mCall))
        } else {
            os_log("Can't update mCall %@ : Because call number is 0", log: log_manager_debug, type: .debug, txtLog)
            mCall = nil
        }
    }
    
    // MARK: - Message notification
    private func onMessageReceived(lc: OpaquePointer?, chatRoom: OpaquePointer?, message: OpaquePointer?) {
        
        // Get call id. For push notification
        let callID = SipChatManager.getMessageCallID(message: message)
        
        // Get remote address string no display name.
        let remoteAddressString = SipUtils.addressToStringNoDisplayName(address: SipChatManager.getMessageRemoteAddress(message: message!))
        
        // Check call id in push messages to stop push lone running background task for notifying message received.
        for (index,id) in pushMessages!.enumerated() where id == callID {
            os_log("Delete push message [%@] in array success, Don't need background task to notify message received", log: log_manager_debug, type: .debug, id)
            pushMessages!.remove(at: index)
        }
        // Check another push call id for needed background task.
        var needBGTask = false
        if pushMessages!.count != 0 {
            os_log("Still need background task to notify message received", log: log_manager_debug, type: .debug)
            needBGTask = true
        }
        if pushMsgBGTask != .invalid && !needBGTask {
            os_log("Push messages clear, Stop message background task", log: log_manager_debug, type: .debug)
            UIApplication.shared.endBackgroundTask(pushMsgBGTask)
            pushMsgBGTask = .invalid
            pushMessages! = []
        }
        os_log("Push messages array : %@", log: log_manager_debug, type: .debug, pushMessages ?? "")
        
        // Check message that is text only. (file transfer not support yet)
        if Int(linphone_chat_message_is_text(message)).boolValue || Int(linphone_chat_message_is_file_transfer(message)).boolValue {
            os_log("Message is text or file transfer", log: log_manager_debug, type: .debug)
            os_log("Content-Type : %@", log: log_manager_debug, type: .debug, String(cString: linphone_chat_message_get_content_type(message)))
            
            let messageText = SipChatManager.getMessageText(message: message)
            
            let dictionary: [AnyHashable:Any] = ["chatRoom" : chatRoom! , "remoteAddress" : remoteAddressString , "message" : message! , "text" : messageText , "callID" : callID ]
            
            // Post notification on main thread.
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .kLinphoneMessageReceived, object: self, userInfo: dictionary)
            }
        } else {
            os_log("Message is not text or file transfer, Content-Type is difference", log: log_manager_debug, type: .debug)
            os_log("Content-Type : %@", log: log_manager_debug, type: .debug, String(cString: linphone_chat_message_get_content_type(message)))
        }
    }
    private func onMessageComposingReceived(lc: OpaquePointer?, chatRoom: OpaquePointer?) {
        
        let dictionary: [AnyHashable:Any] = ["chatRoom" : chatRoom!]
        
        // Post notification on main thread.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kLinphoneMessageComposeReceived, object: self, userInfo: dictionary)
        }
        
    }
    private func onMessageStateChange(message : OpaquePointer?, messageState: LinphoneChatMessageState) {
        
        // Get message state to string.
        let stateStr = SipUtils.messageStateToString(messageState: messageState)
        // Get chat room from message.
        let chatRoom = linphone_chat_message_get_chat_room(message)
        
        let dictionary: [AnyHashable:Any] = ["message" : message!, "state" : stateStr, "chatRoom" : chatRoom!]
        
        // Post notification on main thread.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kLinphoneMessageStateUpdate, object: self, userInfo: dictionary)
        }
    }
    
    // MARK: - File path
    /**
     Get a bundle path and concatenation with file name.
     - parameters:
        - file: a file name of a bundle, Example - [file] parameter should be "ringtone.wav".
     - returns: a full bundle path.
     */
    public func bundleFile(file: String) -> String? {
        
        let filePath = file as NSString
        let path = Bundle.main.path(forResource: filePath.deletingPathExtension, ofType: filePath.pathExtension)
        os_log("Bundle Path : %@", log: log_manager_debug, type: .debug, path ?? "nil")
        return path
        
    }
    
    /**
     Get a user's home directory in a device or simulator and concatenation with file name, Use to install user's personal items.
     - parameters:
        - file: a file name of a resource.
     - returns: a full resource path.
     */
    public func documentFile(file: String) -> String? {
        
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentsPath = (paths[0] as NSString).appendingPathComponent(file)
        os_log("Document Path : %@", log: log_manager_debug, type: .debug, documentsPath)
        return documentsPath
        
    }
    
    /**
     Create a cache path directory if not exist in user's home directory, Use to store user certificate for DTLS connection.
     - returns: a cache path of the device.
     */
    public func cacheDirectory() -> String {
        
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let cachePath = paths[0]
        var isDir: ObjCBool = false
        let fileManager = FileManager.default
        if !(fileManager.fileExists(atPath: cachePath, isDirectory: &isDir)) && isDir.boolValue == false {
            do {
                try fileManager.createDirectory(atPath: cachePath, withIntermediateDirectories: false, attributes: nil)
                os_log("Cache path is created", log: log_manager_debug, type: .debug)
            } catch {
                os_log("Create cache directory => Error : %@", log: log_manager_error, type: .error, error as CVarArg)
            }
            
        }
        os_log("Cache Path : %@", log: log_manager_debug, type: .debug, cachePath)
        return cachePath
        
    }
    
    // MARK: - Edit/Create linphone config
    /* Removing existing config file path store in device/simulator */
    fileprivate func renameDefaultSettings() {
        
        let src = documentFile(file: ".linphonerc")!
        let dst = documentFile(file: "linphonerc")!
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: src) {
            if fileManager.fileExists(atPath: dst) {
                do {
                    try fileManager.removeItem(atPath: src)
                    os_log("%@ : Already exist, Removing setting file path : %@", log: log_manager_debug, type: .debug, dst, src)
                } catch {
                    os_log("Removing setting file from path : %@ => Error : %@", log: log_manager_error, type: .error, src, error as CVarArg)
                }
            } else {
                do {
                    try fileManager.moveItem(atPath: src, toPath: dst)
                    os_log("Moving setting file path successful", log: log_manager_debug, type: .debug)
                } catch {
                    os_log("Moving setting file from path : %@ => Error : %@", log: log_manager_error, type: .error, src, error as CVarArg)
                }
            }
        }
        
    }
    
    /* Copy bundle config file to store in device/simulator */
    fileprivate func copyDefaultSettings() {
        
        let src = bundleFile(file: "linphonerc")
        let dst = documentFile(file: "linphonerc")
        if src != nil && dst != nil {
            copyFile(src: src!, dst: dst!, override: false)
        } else {
            os_log("No Linphone User Config File", log: log_manager_error, type: .error)
            return
        }
        
    }
    
    /* Creating linphone config by merging user config with factory config */
    fileprivate func overrideDefaultSettings() {
        
        let factoryCF = bundleFile(file: "linphonerc-factory")
        let userCF = documentFile(file: "linphonerc")
        os_log("User Config Path : %@", log: log_manager_debug, type: .debug, userCF ?? "nil")
        os_log("Factory Config Path : %@", log: log_manager_debug, type: .debug, factoryCF ?? "nil")
        if factoryCF != nil && userCF != nil {
            // Create unsafePointer to both path.
            userConfigPathPt = userCF!.stringToUnsafePointerInt8()
            factoryConfigPathPt = factoryCF!.stringToUnsafePointerInt8()
            // Create linphone config.
            lpConfig = linphone_config_new_with_factory(userConfigPathPt, factoryConfigPathPt)
        } else {
            os_log("No Linphone User/Factory Config File", log: log_manager_error, type: .error)
            return
        }
        
        
    }
    
    /* Copy file function */
    fileprivate func copyFile(src: String, dst: String, override: Bool) {
        
        let fileManager = FileManager.default
        // If the bundle file is not exist.
        if !fileManager.fileExists(atPath: src) {
            os_log("Can not find resource path : %@", log: log_manager_error, type: .error, src)
            return
        }
        
        // If the bundle file is already store in device/simulator.
        if fileManager.fileExists(atPath: dst) {
            if override {
                do {
                    try fileManager.removeItem(atPath: dst)
                } catch {
                    os_log("Can not remove resource file path : %@ => Error : %@", log: log_manager_error, type: .error, dst, error as CVarArg)
                    return
                }
            } else {
                os_log("%@ : Already exist", log: log_manager_debug, type: .debug, dst)
                return
            }
        }
        
        // Copy bundle resource file path to store device/simulator path
        do {
            try fileManager.copyItem(atPath: src, toPath: dst)
        } catch {
            os_log("Can not copy %@ to %@ => Error : %@", log: log_manager_error, type: .error, src, dst, error as CVarArg)
            return
        }
        
    }

    /* Prepare other linphonecore settings */
    fileprivate func finishCoreConfiguration() {
        
        // Force keep alive to workaround push notif on chat message.
        linphone_core_enable_keep_alive(theLinphoneCore, UInt8(true.intValue))
        
        // Creeate file.
        let zrtpSecretsFileName = documentFile(file: "zrtp_secrets")
        let chatDBFileName = documentFile(file: kLinphoneInternalChatDBFilename)
        
        // Create device format.
        var device = String(format: "%@_%@_iOS%@", Bundle.main.displayName, SipUtils.deviceModelIdentifier(), self.device.systemVersion)
        device = device.replacingOccurrences(of: ",", with: ".")
        device = device.replacingOccurrences(of: " ", with: ".")
        os_log("Device format is : %@", log: log_manager_debug, type: .debug, device)
        
        // Create unsafePointer.
        let devicePt = device.stringToUnsafePointerInt8()
        let linphoneiOSVersionPt = LINPHONE_IOS_VERSION.stringToUnsafePointerInt8()
        let zrtpSecretsFileNamePt = zrtpSecretsFileName!.stringToUnsafePointerInt8()
        let chatDBFileNamePt = chatDBFileName!.stringToUnsafePointerInt8()
        
        // Set user agent to linphone.
        linphone_core_set_user_agent(theLinphoneCore, devicePt, linphoneiOSVersionPt)
        // Set ZRTP file.
        linphone_core_set_zrtp_secrets_file(theLinphoneCore, zrtpSecretsFileNamePt)
        // Set chat database.
        linphone_core_set_chat_database_path(theLinphoneCore, chatDBFileNamePt)
        // Set call log.
        linphone_core_set_call_logs_database_path(theLinphoneCore, chatDBFileNamePt)
        
        // Setup network reachability.
        setupNetworkReachabilityCallback()
        
        // Enable audio and video codecs.
        enabledCodec()
        
        // Set other things.
        linphone_core_set_media_encryption_mandatory(theLinphoneCore, UInt8(false.intValue))
        
        //linphone_core_set_audio_port_range(theLinphoneCore, (20001 as NSNumber).int32Value, (20999 as NSNumber).int32Value)
        
        //let linphoneVideoPolicy = linphone_factory_create_video_activation_policy(linphone_factory_get())
        //linphone_video_activation_policy_set_automatically_initiate(linphoneVideoPolicy, UInt8(true.intValue))
        //linphone_video_activation_policy_set_automatically_accept(linphoneVideoPolicy, UInt8(true.intValue))
        //linphone_core_set_video_activation_policy(theLinphoneCore, linphoneVideoPolicy)
        
        //linphone_core_enable_video_capture(theLinphoneCore, UInt8(true.intValue))
        //linphone_core_enable_video_display(theLinphoneCore, UInt8(true.intValue))
        //linphone_core_enable_video_preview(theLinphoneCore, UInt8(true.intValue))
        //linphone_core_set_preferred_video_size_by_name(theLinphoneCore, "vga".stringToUnsafePointerInt8())
        
        linphone_core_set_media_encryption(theLinphoneCore, LinphoneMediaEncryptionNone)
        linphone_core_enable_adaptive_rate_control(theLinphoneCore, UInt8(true.intValue))
        linphone_core_enable_ipv6(theLinphoneCore, UInt8(false.intValue))
        linphone_core_enable_echo_cancellation(theLinphoneCore, UInt8(true.intValue))
        linphone_core_set_inc_timeout(theLinphoneCore, Int32(60))
        
        // Using custom ringtone.
        enabledDeviceRingtone(use: false)
        
        // Set the static picture.
        let path: String? = bundleFile(file: "no_video.jpg")
        if let unwrapPath = path {
            os_log("Using %@ as source image for no webcam", log: log_manager_debug, type: .debug, unwrapPath)
            let imagePath = (unwrapPath as NSString).cString(using: String.Encoding.utf8.rawValue)
            linphone_core_set_static_picture(theLinphoneCore, imagePath!);
        }
        
        // Set default using camera.
        setDefaultCamera()
        
        // Disable SILK payload type in iPhone3G.
        if !isNotIphone3G() {
            let type = "SILK".stringToUnsafePointerInt8()
            let disable: bool_t = UInt8(false.intValue)
            if let foundPt = linphone_core_get_payload_type(theLinphoneCore, type, 24000, -1) {
                linphone_payload_type_enable(foundPt, disable)
                os_log("SILK/24000 and video disabled on old iPhone 3G", log: log_manager_debug, type: .debug)
            }
            linphone_core_enable_video_display(theLinphoneCore, disable)
            linphone_core_enable_video_capture(theLinphoneCore, disable)
        }
        
        // Enable user presence and publish message.
        // enableProxyPublish(enabled: (UIApplication.shared.applicationState == .active))
        
        os_log("Linphone %@ started on %@", log: log_manager_debug, type: .debug, String(cString:linphone_core_get_version()), self.device.model)

        // Post notification.
        let dictionary: [AnyHashable:Any] = ["core":theLinphoneCore ?? "nil"]
        NotificationCenter.default.post(name: .kLinphoneCoreUpdate, object: SipUAManager.instance(), userInfo: dictionary)
        
    }
    
    /* Enable publish message and set user presence */
    internal func enableProxyPublish(enable: Bool) {
        
        // Check is linphone ready.
        if linphone_core_get_global_state(theLinphoneCore) != LinphoneGlobalOn {
            os_log("Not changing presence configuration because linphone core not ready yet", log: log_manager_debug, type: .debug)
            return
        }
        
        // Read presence from config.
        if lpConfigGetBoolForKey(key: "publish_presence", section: LINPHONERC_APPLICATION_KEY, defaultValue: false) {
            if enable {
                // Set user presence to on TV.
                linphone_core_set_presence_model(
                    theLinphoneCore, linphone_core_create_presence_model_with_activity(theLinphoneCore, LinphonePresenceActivityTV, nil))
                os_log("Set presence activity to TV", log: log_manager_debug, type: .debug)
            }
            
            // Enable publish to proxy config to tell presence user status (online, offline, tv, etc.).
            let prxCfgList = linphone_core_get_proxy_config_list(theLinphoneCore)
            var prxCfg = prxCfgList?.pointee
                while prxCfg != nil {
                    if let prxCfgData = prxCfg?.data {
                        let prxCfgDataPt = OpaquePointer(prxCfgData)
                        linphone_proxy_config_edit(prxCfgDataPt)
                        linphone_proxy_config_enable_publish(prxCfgDataPt, UInt8(enable.intValue))
                        linphone_proxy_config_done(prxCfgDataPt)
                    }
                    if (prxCfg?.next) != nil {
                        prxCfg = prxCfg?.next.pointee
                    } else {
                        break
                    }
                }
            
            // Refresh linphonecore once.
            linphone_core_iterate(theLinphoneCore)
        }
        
    }
    
    // MARK: - Read/Write linphone config
    /* Set string to config */
    internal func lpConfigSetStringForKey(value: String?, key: String?, section: String) {
        
        var keyPt: UnsafePointer<Int8>?
        var valuePt: UnsafePointer<Int8>?
        
        // Unwrap optianal string and create unsafePointer.
        if let unwrapKey = key {
            keyPt = unwrapKey.stringToUnsafePointerInt8()
        } else {
            os_log("Key is nil", log: log_manager_error, type: .error)
            return
        }
        if let unwrapValue = value {
            valuePt = unwrapValue.stringToUnsafePointerInt8()
        } else {
            valuePt = nil
        }
        
        let sectionPt = section.stringToUnsafePointerInt8()
        // Set string to config.
        if lpConfig != nil {
            linphone_config_set_string(lpConfig, sectionPt, keyPt, valuePt)
        } else {
            os_log("Linphone config is nil", log: log_manager_error, type: .error)
            return
        }
        
    }
    
    /* Get string of config */
    internal func lpConfigGetStringForKey(key: String?, section: String, defaultValue: String?) -> String? {
        
        var keyPt: UnsafePointer<Int8>?
        
         // Unwrap optianal string.
        if let unwrapKey = key {
            keyPt = unwrapKey.stringToUnsafePointerInt8()
        } else {
            os_log("Key is nil", log: log_manager_error, type: .error)
            return defaultValue
        }
        
        // Create unsafePointer.
        let sectionPt = section.stringToUnsafePointerInt8()
        // Get string in config.
        if lpConfig != nil {
            let valuePt = linphone_config_get_string(lpConfig, sectionPt, keyPt, defaultValue)
            // Unwrap optianal.
            if let unwrapValuePt = valuePt {
                // Convert unsafePointer to string.
                return String(cString: unwrapValuePt)
            } else {
                os_log("Get config string is nil", log: log_manager_error, type: .error)
                return defaultValue
            }
        } else {
            os_log("Linphone config is nil", log: log_manager_error, type: .error)
            return defaultValue
        }
        
    }
    
    /* Set int to config */
    internal func lpConfigSetIntForKey(value: Int, key: String?, section: String) {
        
        var keyPt: UnsafePointer<Int8>?
        
        // Unwrap optianal string.
        if let unwrapKey = key {
            keyPt = unwrapKey.stringToUnsafePointerInt8()
        } else {
            os_log("Key is nil", log: log_manager_error, type: .error)
            return
        }
        
        // Create unsafePointer.
        let sectionPt = section.stringToUnsafePointerInt8()
        // Convert int to int32.
        let valueInt32 = Int32(value)
        // Set int to config.
        if lpConfig != nil {
            linphone_config_set_int(lpConfig, sectionPt, keyPt, valueInt32)
        } else {
            os_log("Linphone config is nil", log: log_manager_error, type: .error)
            return
        }
        
    }
    
    /* Get int of config */
    internal func lpConfigGetIntForKey(key: String?, section: String, defaultValue: Int) -> Int {
        
        var keyPt: UnsafePointer<Int8>?
        
        // Unwrap optianal string.
        if let unwrapKey = key {
            keyPt = unwrapKey.stringToUnsafePointerInt8()
        } else {
            os_log("Key is nil", log: log_manager_error, type: .error)
            return defaultValue
        }
        
        // Create unsafePointer.
        let sectionPt = section.stringToUnsafePointerInt8()
        // Convert int to int32.
        let valueInt32 = Int32(defaultValue)
        // Get int in config.
        if lpConfig != nil {
            let value = Int(linphone_config_get_int(lpConfig, sectionPt, keyPt, valueInt32))
            return value
        } else {
            os_log("Linphone config is nil", log: log_manager_error, type: .error)
            return defaultValue
        }
        
    }
    
    /* Set boolean to config */
    internal func lpConfigSetBoolForKey(value: Bool, key: String, section: String) {
        // Set boolean to config.
        lpConfigSetIntForKey(value: value.intValue, key: key, section: section)
    }
    
    /* Get boolean in config */
    internal func lpConfigGetBoolForKey(key: String?, section: String, defaultValue: Bool) -> Bool {
        
        var keyPt: UnsafePointer<Int8>?
        
        // Unwrap optianal string.
        if let unwrapKey = key {
            keyPt = unwrapKey.stringToUnsafePointerInt8()
        } else {
            os_log("Key is nil", log: log_manager_error, type: .error)
            return defaultValue
        }
        
        // Convert boolean to int and then int32.
        let defaultValueInt32 = Int32(defaultValue.intValue)
        // Get boolean in config.
        if lpConfig != nil {
            let value = linphone_config_get_int(lpConfig, section, keyPt, defaultValueInt32)
            return (value != -1) ? (value == 1) : false
        } else {
            os_log("Linphone config is nil", log: log_manager_error, type: .error)
            return defaultValue
        }
        
    }
    
    // MARK: - Bridge function
    /**
     Convert an instance of class to pointer with reference counting 0
     - parameters:
        - obj: Any object to create pointer.
     - returns: an UnsafeRawPointer point to the instance.
     */
    public func bridge<T : AnyObject>(obj: T) -> UnsafeRawPointer {
        return UnsafeRawPointer(Unmanaged.passUnretained(obj).toOpaque())
    }
    
    /**
     Convert a pointer to any object with reference counting 0.
     - parameters:
        - ptr: an UnsafeRawPointer.
     - returns: an any object.
     */
    public func bridge<T : AnyObject>(ptr: UnsafeRawPointer) -> T {
        return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
    }
    
    /**
     Convert an instance of class to pointer with reference counting 1.
     - parameters:
        - obj: Any object to create pointer.
     - returns: an UnsafeMutableRawPointer point to the instance.
     */
    public func bridgeRetained<T : AnyObject>(obj: T) -> UnsafeMutableRawPointer {
        return Unmanaged.passRetained(obj).toOpaque()
    }
    
    /**
     Convert a pointer to any object with reference counting 1.
     - parameters:
        - ptr: an UnsafeRawPointer.
     - returns: an any object.
     */
    public func bridgeRetained<T : AnyObject>(ptr: UnsafeRawPointer) -> T {
        return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
    }
    
    /**
     Convert an instance of class to pointer with no reference counting.
     - parameters:
        - obj: Any object to create pointer.
     - returns: an UnsafeMutableRawPointer point to the instance.
     */
    public func bridgeUnretained<T : AnyObject>(obj: T) -> UnsafeMutableRawPointer {
        return Unmanaged.passUnretained(obj).toOpaque()
    }
    
    /**
     Convert a pointer to any object with no reference counting.
     - parameters:
        - ptr: an UnsafeRawPointer.
     - returns: an any object.
     */
    public func bridgeUnretained<T : AnyObject>(ptr: UnsafeRawPointer) -> T {
        return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
    }
    
    // MARK: - Application mode
    /* Turn off sleep mode */
    internal func turnOffSleepMode() {
        os_log("Turn off sleep mode, Dim a display is disabled, It might consume a power!", log: log_manager_debug, type: .debug)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    /* Turn on sleep mode */
    internal func turnOnSleepMode() {
        os_log("Turn on sleep mode, Dim a display is enabled", log: log_manager_debug, type: .debug)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    /**
     Enable push notification in default proxy config.
     - parameters:
        - enable:
     
            true, To add push_notification string in ref key.
     
            false, To add no_push_notification in ref key.
     */
    public func enablePushNotification(enable: Bool) {
        if let prxCfg = linphone_core_get_default_proxy_config(theLinphoneCore) {
            if enable {
                linphone_proxy_config_set_ref_key(prxCfg, push_notification.stringToUnsafePointerInt8())
            } else {
                linphone_proxy_config_set_ref_key(prxCfg, no_push_notification.stringToUnsafePointerInt8())
            }
        } else {
            os_log("No default proxy config", log: log_manager_error, type: .error)
            return
        }
    }
    
    /**
     Enable push notification in specific proxy config.
     - parameters:
        - config: a specific linphone proxy config.
        - enable:
     
            true, To add push_notification string in ref key.
     
            false, To add no_push_notification in ref key.
     */
    public func enablePushNotification(config: OpaquePointer, enable: Bool) {
        if checkConfigExist(config: config) {
            if enable {
                linphone_proxy_config_set_ref_key(config, push_notification.stringToUnsafePointerInt8())
            } else {
                linphone_proxy_config_set_ref_key(config, no_push_notification.stringToUnsafePointerInt8())
            }
        } else {
            os_log("Proxy config is not exist", log: log_manager_error, type: .error)
            return
        }
    }
    
    /**
     Check default proxy config is enabled notification or not.
     - returns:
     
        true, If push_notification string is added in ref key.
     
        false, If push_notification string is not added in ref key.
     */
    public func isEnabledPushNotification() -> Bool {
        if let prxCfg = linphone_core_get_default_proxy_config(theLinphoneCore) {
            let refKeyStr = String(cString: linphone_proxy_config_get_ref_key(prxCfg))
            os_log("Push notification for default proxy config : %@", log: log_manager_debug, type: .debug, (refKeyStr == push_notification) ? "enable" : "disable")
            if refKeyStr == push_notification {
                return true
            } else {
                return false
            }
        } else {
            os_log("No default proxy config", log: log_manager_error, type: .error)
            return false
        }
    }
    
    /**
     Check a specific proxy config is enabled notification or not.
     - parameters:
        - config: a linphone proxy config.
     - returns:
     
        true, If push_notification string is added in ref key.
     
        false, If push_notification string is not added in ref key.
     */
    public func isEnabledPushNotification(config: OpaquePointer) -> Bool {
        let refKeyStr = String(cString: linphone_proxy_config_get_ref_key(config))
        os_log("Push notification for user : %@ | %@", log: log_manager_debug, type: .debug, SipUtils.getIdentityUsernameFromConfig(config: config) ?? "", (refKeyStr == push_notification) ? "enable" : "disable")
        if refKeyStr == push_notification {
            return true
        } else {
            return false
        }
    }
    
    /**
     Enter background mode.
     */
    public func enterBackgroundMode() {
        
        // Tell linphone core to enter background.
        linphone_core_enter_background(theLinphoneCore)
        
        // Turn off publish.
        // enableProxyPublish(enabled: false)
        
        // Get default proxy config to check reference key.
        let prxConfig = linphone_core_get_default_proxy_config(theLinphoneCore)
        var pushNotificationEnable = false
        if prxConfig != nil {
            let refKey = linphone_proxy_config_get_ref_key(prxConfig!)
            os_log("Reference key for default proxy config : %@", log: log_manager_debug, type: .debug, refKey != nil ? String(cString: refKey!) : "nil")
            pushNotificationEnable = (refKey != nil && strcmp(refKey, push_notification.stringToUnsafePointerInt8()) == 0)
            if pushNotificationEnable {
                // Refresh register to update server with push token.
                refreshRegister()
            }
        }
        
        // If there is some paused call. Start background task.
        let currentCall = getCurrentCall()
        let allCalls = getAllCalls()
        var hasPausedCall: Bool = false
        for call in allCalls where getStateOfCall(call: call) == LinphoneCallStatePaused {
            hasPausedCall = true
            break
        }
        if currentCall == nil && allCalls.count != 0 && hasPausedCall {
            os_log("No running call and found paused call, Start paused call background task", log: log_manager_debug, type: .debug)
            startCallPausedLongRunningTask()
        }
        
        // Disable video preview.
        if LC != nil {
            os_log("Disable video preview", log: log_manager_debug, type: .debug)
            linphone_core_enable_video_preview(theLinphoneCore, UInt8(false.intValue))
            iterate()
        }
        
        /*
        if allCalls.count == 0 && floor(NSFoundationVersionNumber) <= Double(NSFoundationVersionNumber_iOS_9_x_Max) && prxConfig != nil {
            os_log("No any call and iOS version is less than or equal 9.x", log: log_manager_debug, type: .debug)
            let refKey = linphone_proxy_config_get_ref_key(prxConfig!)
            os_log("Reference key for default proxy config : %@", log: log_manager_debug, type: .debug, refKey != nil ? String(cString: refKey!) : "nil")
            pushNotificationEnable = (refKey != nil && strcmp(refKey, push_notification.stringToUnsafePointerInt8()) == 0)
            if pushNotificationEnable {
                os_log("Keep linphone core handle push, Set connectivity type to none and set network reachable to false", log: log_manager_debug, type: .debug)
                connectivity = .none
                linphone_core_set_network_reachable(theLinphoneCore, UInt8(false.intValue))
            }
        }
        */
        
    }
    
    /**
     Exit background mode.
     */
    public func becomeActive() {
        
        // Tell linphone core to enter foreground.
        linphone_core_enter_foreground(theLinphoneCore)
        
        // Refresh register.
        //if floor(NSFoundationVersionNumber) <= Double(NSFoundationVersionNumber_iOS_9_x_Max) || connectivity == .none {
        refreshRegister()
        //}
        
        // Stop background task for paused call.
        if pausedCallBGTask != UIBackgroundTaskIdentifier.invalid {
            os_log("End paused call background task", log: log_manager_debug, type: .debug)
            UIApplication.shared.endBackgroundTask(pausedCallBGTask)
            pausedCallBGTask = UIBackgroundTaskIdentifier.invalid
        }
        
        // Request video access, Just in case.
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { (granted: Bool) in
            if granted {
                os_log("Video permission is already allow", log: log_manager_debug, type: .debug)
            } else {
                os_log("Video permission is not allow", log: log_manager_debug, type: .debug)
            }
        }
        
        // Enable remote video preview.
        if LC != nil {
            linphone_core_enable_video_preview(theLinphoneCore, UInt8(true.intValue))
        }
        
        // Turn on publish.
        // enableProxyPublish(enabled: true)
        
    }
    
    /**
     Start background task for paused call.
     */
    public func startCallPausedLongRunningTask() {
        
        // Start background task for paused call.
        pausedCallBGTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            os_log("Background task for paused call is invalid", log: log_manager_debug, type: .debug)
            UIApplication.shared.endBackgroundTask(self.pausedCallBGTask)
        })
        os_log("Paused call background task starting, Time remaining : %@", log: log_manager_debug, type: .debug, SipUtils.intervalToString(interval: UIApplication.shared.backgroundTimeRemaining))

    }
    
    /**
     Add an incoming push call/message call id to show a missed call or message received notification.
     - parameters:
        - category: a category of notification as string.
        - callID: an identifier of notification as string.
     - returns:
     
        true, If add success.
     
        fasle, If add fail.
     */
    public func addCallIDForLongTaskBG(category: String?, callID: String?) -> Bool {
        if callID == nil || callID == "" || category == nil || category == "" {
            os_log("Input value is nil or empty, Add fail", log: log_manager_error, type: .error)
            return false
        }
        os_log("Category : %@", log: log_manager_debug, type: .debug, category!)
        os_log("Call id : %@", log: log_manager_debug, type: .debug, callID!)
        if category == "Call" {
            for call in getAllCalls() where getCallCallID(call: call) == callID {
                os_log("Cal id for this call is already received, Add fail", log: log_manager_error, type: .error)
                return false
            }
            for id in pushCalls! where id == callID {
                os_log("Call id is already added to push calls array, Add fail", log: log_manager_error, type: .error)
                return false
            }
            pushCalls!.append(callID!)
            os_log("Call id is added to push calls array, Add success", log: log_manager_debug, type: .debug)
            os_log("Push calls array : %@", log: log_manager_debug, type: .debug, pushCalls ?? "nil" )
            return true
        } else if category == "Message" {
            // If push comes after received message, Don't add to push message dictionary.
            if getMessageFromCallID(callID: callID) != nil {
                os_log("Call id for this message is already received, Add fail", log: log_manager_error, type: .error)
                return false
            }
            for id in pushMessages! where id == callID {
                os_log("Call id is already added to push mesages array, Add fail", log: log_manager_error, type: .error)
                return false
            }
            pushMessages!.append(callID!)
            os_log("Call id is added to push messages array, Add success", log: log_manager_debug, type: .debug)
            os_log("Push messages array : %@", log: log_manager_debug, type: .debug, pushMessages ?? "nil" )
            return true
        }
        os_log("Category is not match, Add fail", log: log_manager_debug, type: .debug)
        os_log("Push calls array : %@", log: log_manager_debug, type: .debug, pushCalls ?? "nil" )
        os_log("Push messages array : %@", log: log_manager_debug, type: .debug, pushMessages ?? "nil" )
        return false
    }
    
    /**
     Start background task to show notification if timeout for incoming push (call/message).
     - parameters:
        - category: a category of notification as string.
        - callID: an identifier of notification as string.
     */
    public func startPushLongRunningTask(category: String?, callID: String?) {
        if (callID == nil || callID == "") || (category == nil || category == "") {
            os_log("Input value is nil or empty, Can't start push long running task", log: log_manager_debug, type: .debug)
            return
        }
        os_log("Category : %@", log: log_manager_debug, type: .debug, category!)
        os_log("Call id : %@", log: log_manager_debug, type: .debug, callID!)
        if category == "Call" {
            UIApplication.shared.endBackgroundTask(pushCallBGTask)
            pushCallBGTask = .invalid
            pushCallBGTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                if UIApplication.shared.applicationState != .active {
                    let content = UNMutableNotificationContent()
                    content.title = "Missed call."
                    content.body = "You have missed a call."
                    content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "ringchat.wav"))
                    let request = UNNotificationRequest(identifier: "Missed call", content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error: Error?) in
                        if error != nil {
                            os_log("Add local notification error", log: log_manager_error, type: .error)
                        }
                    })
                }
                os_log("Clear all call id in push calls array", log: log_manager_debug, type: .debug)
                self.pushCalls = []
                UIApplication.shared.endBackgroundTask(self.pushCallBGTask)
                self.pushCallBGTask = .invalid
            })
            os_log("Push calls array : %@", log: log_manager_debug, type: .debug, pushCalls ?? "")
            os_log("Call long running task started for call id : %@ ,Because push has been received", log: log_manager_debug, type: .debug, callID!)
            os_log("Time remaining : %@", log: log_manager_debug, type: .debug, SipUtils.intervalToString(interval: UIApplication.shared.backgroundTimeRemaining))
        } else if category == "Message" {
            UIApplication.shared.endBackgroundTask(pushMsgBGTask)
            pushMsgBGTask = .invalid
            pushMsgBGTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                if UIApplication.shared.applicationState != .active {
                    let content = UNMutableNotificationContent()
                    content.title = "Message received."
                    content.body = "You have received a message."
                    content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "ringchat.wav"))
                    let request = UNNotificationRequest(identifier: "Message received", content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error: Error?) in
                        if error != nil {
                            os_log("Add local notification error", log: log_manager_error, type: .error)
                        }
                    })
                }
                os_log("Clear all call id in push messages array", log: log_manager_debug, type: .debug)
                self.pushMessages = []
                UIApplication.shared.endBackgroundTask(self.pushMsgBGTask)
                self.pushMsgBGTask = .invalid
            })
            os_log("Push messages array : %@", log: log_manager_debug, type: .debug, pushMessages ?? "")
            os_log("Message long running task started for call id : %@ ,Because push has been received", log: log_manager_debug, type: .debug, callID!)
            os_log("Time remaining : %@", log: log_manager_debug, type: .debug, SipUtils.intervalToString(interval: UIApplication.shared.backgroundTimeRemaining))
        }
    }
    
    /**
     Set notification token to default proxy config or another config that enable to set.
     - parameters:
        - token: a notification token to set.
     */
    public func setPushNotificationToken(token: Data?) {
        
        // If token is the same. Return.
        if pushNotificationToken == token {
            os_log("Push token is already set", log: log_manager_debug, type: .debug)
            return
        }
        
        // Set new token.
        pushNotificationToken = token
        // Check new token not nil.
        if let token = pushNotificationToken {
            let tmpToken = token.map({ (data) -> String in
                String(format: "%02.2hhx", data)
            }).joined()
            os_log("Push token has been set to %@", log: log_manager_debug, type: .debug, tmpToken)
        } else {
            os_log("Push token has been set to nil", log: log_manager_debug, type: .debug)
        }

        // Configure push token.
        if let prxCfg = linphone_core_get_default_proxy_config(theLinphoneCore) {
            configurePushTokenForProxyConfig(proxyConfig: prxCfg)
        } else {
            os_log("No default proxy config to set push token", log: log_manager_debug, type: .debug)
            os_log("Check all proxy config to set push token", log: log_manager_debug, type: .debug)
            let prxCfgList = linphone_core_get_proxy_config_list(theLinphoneCore)
            os_log("Count all proxy config : %i", log: log_manager_debug, type: .debug, bctbx_list_size(prxCfgList))
            var prxCfg = prxCfgList?.pointee
            while prxCfg != nil {
                if let prxData = prxCfg?.data {
                    let prxPointer = OpaquePointer(prxData)
                    configurePushTokenForProxyConfig(proxyConfig: prxPointer)
                }
                if (prxCfg?.next) != nil {
                    prxCfg = prxCfg?.next.pointee
                } else {
                    break
                }
            }
        }
    }
    
    /**
     Get push notification token from library.
     - returns: a token as data.
     */
    public func getPushNotificationToken() -> Data? {
        return pushNotificationToken
    }
    
    /* Set a push token in proxy config */
    private func configurePushTokenForProxyConfig(proxyConfig: OpaquePointer) {
        let identityAddress = linphone_proxy_config_get_identity_address(proxyConfig)
        let identityAddressString = linphone_address_as_string(identityAddress)
        
        // Start editing proxy config.
        linphone_proxy_config_edit(proxyConfig)
        
        // Get token.
        let tokenData = pushNotificationToken
        // Get ref key from proxy config.
        let refKey = linphone_proxy_config_get_ref_key(proxyConfig)
        let pushNotificationEnable = (refKey != nil && strcmp(refKey, push_notification.stringToUnsafePointerInt8()) == 0)
        
        if tokenData != nil && pushNotificationEnable {
            // Convert token to string.
            let tokenParts = tokenData!.map { (data) -> String in
                String(format: "%02.2hhx", data)
            }
            let tokenString = tokenParts.joined()
            
            // Macros.
            /*
            let APPMODE_SUFFIX: String
            #if DEBUG
                APPMODE_SUFFIX = "dev"
            #else
                APPMODE_SUFFIX = "prod"
            #endif
            */
            
            // Get sound path from config.
            let ringTonePath = lpConfigGetStringForKey(key: "local_ring", section: "sound", defaultValue: nil)
            // If sound path from config is not exist. Get from bundle.
            let ringTone = ringTonePath != nil ? bundleFile(file: (ringTonePath! as NSString).lastPathComponent) ?? "" : bundleFile(file: "ringtone.wav") ?? ""
            let ringMsg = bundleFile(file: "ringchat.wav") ?? ""
            // Set timeout.
            //var timeout: String = ""
            //if floor(NSFoundationVersionNumber) > Double(NSFoundationVersionNumber_iOS_9_x_Max) {
                //timeout = ";pn-timeout=0"
            //}
            
            // Create string for push notification for brekeke server.
            var param: String!
            param = String(format: "app-id=%@;pn-type=1;pn-tok=%@", Bundle.main.bundleIdentifier!, tokenString, ringMsg, ringTone)
//            param = String(format: "app-id=%@;pn-type=1;pn-tok=%@;pn-call-snd=%@;pn-msg-snd=%@%@;pn-silent=1", Bundle.main.bundleIdentifier!, tokenString, ringTone, ringMsg, timeout)
            
            // Add push token.
            os_log("Proxy config [%@] configured for push notifications", log: log_manager_debug, type: .debug, String(cString: identityAddressString!))
            os_log("With contact : [%@]", log: log_manager_debug, type: .debug, param)
            linphone_proxy_config_set_contact_uri_parameters(proxyConfig, param.stringToUnsafePointerInt8())
            linphone_proxy_config_set_contact_parameters(proxyConfig, nil)
            
            os_log("Configure push token for proxy config : %@", log: log_manager_debug, type: .debug, String(cString: identityAddressString!))
        } else {
            // No push token.
            os_log("Proxy config [%@] NOT configured for push notifications", log: log_manager_debug, type: .debug, String(cString: identityAddressString!))
            linphone_proxy_config_set_contact_uri_parameters(proxyConfig, nil)
            linphone_proxy_config_set_contact_parameters(proxyConfig, nil)
        }
        
        // End editing proxy config.
        linphone_proxy_config_done(proxyConfig)
        
    }
    
    // MARK: - Presence Activity RFC 4480 Use for telling the remote that user online or not
    /* Check a presence model is set or not */
    fileprivate func isPresenceModelActivitySet() -> Bool {
        if isInstanciated() && LC != nil {
            let model = linphone_core_get_presence_model(theLinphoneCore)
            let activity = linphone_presence_model_get_activity(model)
            return model != nil && activity != nil
        }
        return false
    }
    
    /**
     Set presence model to TV for publish message.
     */
    public func changeStatusToTV() {
        if isInstanciated() && LC != nil && isPresenceModelActivitySet() {
            let model = linphone_core_get_presence_model(theLinphoneCore)
            let activity = linphone_presence_model_get_activity(model)
            // Check presence activity.
            if linphone_presence_activity_get_type(activity) != LinphonePresenceActivityTV {
                linphone_presence_model_set_activity(model, LinphonePresenceActivityTV, nil)
                linphone_core_set_presence_model(theLinphoneCore, model)
                os_log("Change presence activity to TV", log: log_manager_debug, type: .debug)
            }
        } else if isInstanciated() && LC != nil && !isPresenceModelActivitySet() {
            let model = linphone_core_create_presence_model(theLinphoneCore)
            linphone_presence_model_set_activity(model, LinphonePresenceActivityTV, nil)
            linphone_core_set_presence_model(theLinphoneCore, model)
            os_log("Change presence activity to TV", log: log_manager_debug, type: .debug)
        }
    }
    
    /**
     Set presence model to online for publish message.
     */
    public func changeStatusToOnline() {
        if isInstanciated() && LC != nil {
            if let model = linphone_core_get_presence_model(theLinphoneCore) {
                linphone_presence_model_set_basic_status(model, LinphonePresenceBasicStatusOpen)
                linphone_core_set_presence_model(theLinphoneCore, model)
                os_log("Change presence activity to online", log: log_manager_debug, type: .debug)
            } else {
                let model = linphone_core_create_presence_model(theLinphoneCore)
                linphone_presence_model_set_basic_status(model, LinphonePresenceBasicStatusOpen)
                linphone_core_set_presence_model(theLinphoneCore, model)
                os_log("Change presence activity to online", log: log_manager_debug, type: .debug)
            }
        }
    }
    
    /**
     Set presence model to offline for publish message.
     */
    public func changeStatusToOffline() {
        if isInstanciated() && LC != nil {
            let model = linphone_core_get_presence_model(theLinphoneCore)
            linphone_presence_model_set_basic_status(model, LinphonePresenceBasicStatusClosed)
            linphone_core_set_presence_model(theLinphoneCore, model)
            os_log("Change presence activity to offline", log: log_manager_debug, type: .debug)
        } else {
            let model = linphone_core_create_presence_model(theLinphoneCore)
            linphone_presence_model_set_basic_status(model, LinphonePresenceBasicStatusClosed)
            linphone_core_set_presence_model(theLinphoneCore, model)
            os_log("Change presence activity to offline", log: log_manager_debug, type: .debug)
        }
    }
    
    /**
     Set presence model to on the phone for publish message.
     */
    public func changeStatusToOnThePhone() {
        if isInstanciated() && LC != nil && isPresenceModelActivitySet() {
            let model = linphone_core_get_presence_model(theLinphoneCore)
            let activity = linphone_presence_model_get_activity(model)
            if linphone_presence_activity_get_type(activity) != LinphonePresenceActivityTV {
                linphone_presence_model_set_activity(model, LinphonePresenceActivityOnThePhone, nil)
                linphone_core_set_presence_model(theLinphoneCore, model)
                os_log("Change presence activity to on the phone", log: log_manager_debug, type: .debug)
            }
        } else if isInstanciated() && LC != nil && !isPresenceModelActivitySet() {
            let model = linphone_presence_model_new()
            linphone_presence_model_set_activity(model, LinphonePresenceActivityOnThePhone, nil)
            linphone_core_set_presence_model(theLinphoneCore, model)
            os_log("Change presence activity to on the phone", log: log_manager_debug, type: .debug)
        }
    }
    
    // MARK: - Codecs
    /* Enable default audio and video codec */
    fileprivate func enabledCodec() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        
        let audioCodecsList = linphone_core_get_audio_payload_types(theLinphoneCore)
        os_log("Count all available audio payload type : %i", log: log_manager_debug, type: .debug, bctbx_list_size(audioCodecsList))
        SipAudioManager.enableAudioCodecSet()
        
        let videoCodecsList = linphone_core_get_video_payload_types(theLinphoneCore)
        os_log("Count all available video payload type : %i", log: log_manager_debug, type: .debug, bctbx_list_size(videoCodecsList))
        SipVideoManager.enableVideoCodecSet()
        
    }
    
    /**
     Get audio streaming codec while call is running.
     - returns: a SipPayloadType structure.
     */
    public func getAudioStreamingCodec() -> SipPayloadType {
        var sipPt: SipPayloadType = SipPayloadType()
        if let call = getCurrentCall() {
            let currentParam = linphone_call_get_current_params(call)
            let pt = linphone_call_params_get_used_audio_payload_type(currentParam)
            sipPt.name = String(cString: linphone_payload_type_get_mime_type(pt))
            sipPt.clock_rate = Int(linphone_payload_type_get_clock_rate(pt))
            sipPt.channels = Int(linphone_payload_type_get_channels(pt))
        } else {
            os_log("Current call is nil : Can't get audio streaming codec", log: log_manager_error, type: .error)
        }
        return sipPt
    }
    
    /**
     Get video streaming codec while call is running.
     - returns: a SipPayloadType structure.
     */
    public func getVideoStreamingCodec() -> SipPayloadType {
        var sipPt: SipPayloadType = SipPayloadType()
        if let call = getCurrentCall() {
            let currentParam = linphone_call_get_current_params(call)
            let pt = linphone_call_params_get_used_video_payload_type(currentParam)
            sipPt.name = String(cString: linphone_payload_type_get_mime_type(pt))
            sipPt.clock_rate = Int(linphone_payload_type_get_clock_rate(pt))
            sipPt.channels = Int(linphone_payload_type_get_channels(pt))
        } else {
            os_log("Current call is nil : Can't get video streaming codec", log: log_manager_error, type: .error)
        }
        return sipPt
    }
    
    // MARK: - Messaging
    /**
     Get a specific call id from message.
     - parameters:
        - message: a specific message to get id.
     - returns: a call id as string.
     */
    public func getMessageCallID(message: OpaquePointer?) -> String {
        return SipChatManager.getMessageCallID(message: message)
    }
    
    /**
     Get a remote address of message.
     - parameters:
        - message: a linphone message to get remote address.
     - returns: a linphone remote address.
     */
    public func getMessageRemoteAddress(message: OpaquePointer) -> OpaquePointer {
        return SipChatManager.getMessageRemoteAddress(message: message)
    }
    
    /**
     Get a local address of message.
     - parameters:
        - message: a linphone message to get local address.
     - returns: a linphone local address.
     */
    public func getMessageLocalAddress(message: OpaquePointer) -> OpaquePointer {
        return SipChatManager.getMessageLocalAddress(message: message)
    }
    
    /**
     Get a date of message.
     - parameters:
        - message: a message to get time.
     - returns: a message date as time interval type.
     */
    public func getMessageDate(message: OpaquePointer) -> TimeInterval {
        return SipChatManager.getMessageDate(message: message)
    }
    
    /**
     Get a text of message.
     - parameters:
        - message: a message to get text.
     - returns: a message text as string.
     */
    public func getMessageText(message: OpaquePointer?) -> String {
        return SipChatManager.getMessageText(message: message)
    }
    
    /**
     Get a message from call id.
     - parameters:
        - callID: a call id as string.
     - returns: a message.
     */
    public func getMessageFromCallID(callID: String?) -> OpaquePointer? {
        return SipChatManager.getMessageFromCallID(callID: callID)
    }
    
    /**
     Find message from chatroom. Chat room can set to nil, It will get chat room from message itself.
     - parameters:
        - chatRoom: a chat room to find message.
        - message: a message to find in chat room.
     - returns: a message.
     */
    public func findMessage(chatRoom: OpaquePointer?, message: OpaquePointer) -> OpaquePointer? {
        return SipChatManager.findMessage(chatRoom: chatRoom, message: message)
    }
    
    /**
     Find chat room from local and peer address.
     - parameters:
        - localAddr: a local address as string.
        - peerAddr: a peer address as string.
     - returns: a chat room.
     */
    public func findChatRoom(localAddr: String?, peerAddr: String?) -> OpaquePointer? {
        return SipChatManager.findChatRoom(localAddr: localAddr, peerAddr: peerAddr)
    }
    
    /**
     Check a message is from local or remote.
     - parameters:
        - message: a message to get status.
     - returns:
     
        true, If message has been sent.
     
        false, If message has been received.
     */
    public func isOutgoingMessage(message: OpaquePointer) -> Bool {
        return SipChatManager.isOutgoingMessage(message: message)
    }
    
    /**
     Check a message status is read or not.
     - parameters:
        - message: a message to get status.
     - returns:
     
        true, If message is read.
     
        false, If message is not read.
     */
    public func isMessageRead(message: OpaquePointer) -> Bool {
        return SipChatManager.isMessageRead(message: message)
    }
    
    /**
     Check a message is text or not.
     - parameters:
        - message: a message to check text.
     - returns:
     
        true, If message is text.
     
        false, If message is not text.
     */
    public func isMessageText(message: OpaquePointer) -> Bool {
        return SipChatManager.isMessageText(message: message)
    }
    
    /**
     Delete a message in chat room.
     - parameters:
        - chatRoom: a chat room that has a message in history. Can set to nil it will get chat room from message.
        - message: a message to delete.
     */
    public func deleteMessage(chatRoom: OpaquePointer?, message: OpaquePointer) {
       SipChatManager.deleteMessage(chatRoom: chatRoom, message: message)
    }
    
    /**
     Create a message.
     - parameters:
        - chatRoom: a chat room to create message.
        - message: a message as string.
     - returns: a message.
     */
    public func createMessage(chatRoom: OpaquePointer, message: String) -> OpaquePointer {
        return SipChatManager.createMessage(chatRoom: chatRoom, message: message)
    }
    
    /**
     Send a message.
     - parameters:
        - message: a message to send.
     */
    public func sendMessage(message: OpaquePointer) {
        SipChatManager.sendMessage(message: message)
    }
    
    /**
     Get a message status.
     - parameters:
        - message: a message to get status.
     - returns: a message status as string.
     */
    public func getMessageStatus(message: OpaquePointer) -> String {
        return SipChatManager.getMessageStatus(message: message)
    }
    
    /**
     Setup message state callback for message state change.
     - parameters:
        - message: a message to set callback for message state change.
     */
    public func setupCbForMessageStateChange(message: OpaquePointer) {
        SipChatManager.setupCbForMessageStateChange(message: message)
    }
    
    /**
     Remove message state callback for message state change.
     - parameters:
        - message: a message to remove callback for message state change.
     */
    public func removeCbForMessageStateChange(message: OpaquePointer) {
        SipChatManager.removeCbForMessageStateChange(message: message)
    }
    
    /**
     Get all chat rooms.
     - returns: an array of sorted chat room from newest to oldest.
     */
    public func getAllChatRoom() -> Array<OpaquePointer?> {
        return SipChatManager.getAllChatRoom()
    }
    
    /**
     Delete a chat room.
     - parameters:
        - chatRoom: a chat room to delete.
     */
    public func deleteChatRoom(chatRoom: OpaquePointer) {
        SipChatManager.deleteChatRoom(chatRoom: chatRoom)
    }
    
    /**
     Mark all message in chat room read.
     - parameters:
        - chatRoom: a chat room to mark.
     */
    public func markAsRead(chatRoom: OpaquePointer) {
        SipChatManager.markAsRead(chatRoom: chatRoom)
    }
    
    /**
     Notified remote that local is composing.
     - parameters:
        - chatRoom: a chat room to notified compose.
     */
    public func composeMessage(chatRoom: OpaquePointer) {
        SipChatManager.composeMessage(chatRoom: chatRoom)
    }
    
    /**
     Create chat room with username if chat room doesn't exist.
     - parameters:
        - username: an username as string, Example - If full address is sip:John@testserver.com:5060 then [username] parameter should be John.
     - returns: a chat room.
     */
    public func createChatRoom(username: String) -> OpaquePointer {
        return SipChatManager.createChatRoom(username: username)
    }
    
    /**
     Get a remote address of chat room.
     - parameters:
        - chatRoom: a chat room to get remote address.
     - returns: a remote address.
     */
    public func getChatRoomRemoteAddress(chatRoom: OpaquePointer) -> OpaquePointer {
        return SipChatManager.getChatRoomRemoteAddress(chatRoom: chatRoom)
    }
    
    /**
     Get a local address of chat room.
     - parameters:
        - chatRoom: a chat room to get local address.
     - returns: a local address.
     */
    public func getChatRoomLocalAddress(chatRoom: OpaquePointer) -> OpaquePointer {
        return SipChatManager.getChatRoomLocalAddress(chatRoom: chatRoom)
    }
    
    /**
     Get unread message count of chat room.
     - parameters:
        - chatRoom: a chat room to get unread message count.
     - returns: an unread message count as int.
     */
    public func getChatRoomUnreadMsgCount(chatRoom: OpaquePointer) -> Int {
        return SipChatManager.getChatRoomUnreadMsgCount(chatRoom: chatRoom)
    }
    
    /**
     Get unread message count of all chat room.
     - returns: an unread message count as int.
     */
    public func getAllChatRoomUnreadMsgCount() -> Int {
        return SipChatManager.getAllChatRoomUnreadMsgCount()
    }
    
    /**
     Check a remote chat room is composing or not.
     - parameters:
        - chatRoom: a chat room to get status.
     - returns:
     
        true, If remote chat room is typing.
     
        false, If remote chat room is not typing.
     */
    public func isChatRoomRemoteComposing(chatRoom: OpaquePointer) -> Bool {
        return SipChatManager.isChatRoomRemoteComposing(chatRoom: chatRoom)
    }
    
    /**
     Get a last message of chat room.
     - parameters:
        - chatRoom: a chat room to get message.
     - returns: a last message.
     */
    public func getChatRoomLastMsg(chatRoom: OpaquePointer) -> OpaquePointer? {
        return SipChatManager.getChatRoomLastMsg(chatRoom: chatRoom)
    }
    
    /**
     Get a chat room from message.
     - parameters:
        - message: a message to get chat room.
     - returns: a chat room.
     */
    public func getChatRoomFromMsg(message: OpaquePointer) -> OpaquePointer {
        return SipChatManager.getChatRoomFromMsg(message: message)
    }
    
    /**
     Get all chat message history in chat room.
     - parameters:
        - chatRoom: a chat room to get history chat message.
     - returns: an array of all message in chat room.
     */
    public func getChatRoomAllMsg(chatRoom: OpaquePointer) -> Array<OpaquePointer?> {
        return SipChatManager.getChatRoomAllMsg(chatRoom: chatRoom)
    }
    
    /**
     Get a last message date of chat room.
     - parameters:
        - chatRoom: a chat room to get last message date.
        - dateFormat: a date format to get. Can set to nil it will use default format (HH:mm) for the same day, (dd/MM - HH:mm) for the past day.
     - returns: a last message date as string.
     */
    public func getChatRoomLastMsgDate(chatRoom: OpaquePointer, dateFormat: String?) -> String {
        return SipChatManager.getChatRoomLastMsgDate(chatRoom: chatRoom, dateFormat: dateFormat)
    }
    
    // MARK: - CallKit Audio
    /**
     Enable or disable using CallKit to SipUA library.
     - parameters:
        - enable:
     
            true, To let SipUAAudioManager control audio route/mode.
     
            false, To let CallKit control audio route/mode.
     */
    public func enableCallKit(enable: Bool) {
        useCallKit = enable
    }
    
    /**
     Check using CallKit status from SipUA library.
     - returns:
     
        true, If CallKit is controlling audio route/mode.
     
        false, If SipUAAudioManager is controlling audio route/mode.
     */
    public func isCallKitEnabled() -> Bool {
        return useCallKit
    }
    
    // MARK: - Audio
    /**
     Route audio path to receiver.
     */
    public func routeAudioToReceiver() {
        SipAudioManager.routeAudioToReceiver()
    }
    
    /**
     Route audio path to speaker.
     */
    public func routeAudioToSpeaker() {
        SipAudioManager.routeAudioToSpeaker()
    }
    
    /**
     Route audio path to bluetooth.
     */
    public func routeAudioToBluetooth() {
        SipBluetoothManager.routeAudioToBluetooth()
    }
    
    /**
     Route audio path to headphones.
     */
    public func routeAudioToHeadphones() {
        SipAudioManager.routeAudioToHeadphones()
    }
    
    /**
     Set audio to voice call mode.
     */
    public func setAudioManagerInVoiceCallMode() {
        SipAudioManager.setAudioManagerInVoiceCallMode()
    }
 
    /**
     Set audio to default mode.
     */
    public func setAudioManagerInDefaultMode() {
        SipAudioManager.setAudioManagerInDefaultMode()
    }
    
    /**
     Restart audio session.
     */
    public func restartAudioSession() {
        SipAudioManager.restartAudioSession()
    }
    
    /**
     Check speaker is enabled or disabled.
     - returns:
     
        true, If speaker is on.
     
        false, If speaker is off.
     */
    public func isSpeakerEnabled() -> Bool {
        return SipUAAudioManager.speakerEnabled
    }
    
    /**
     Check bluetooth is connected or not.
     - returns:
     
        true, If bluetooth is connected.
     
        false, If bluetooth is not connected.
     */
    public func isBluetoothConnected() -> Bool {
        return SipUABluetoothManager.bluetoothConnected
    }
    
    /**
     Check bluetooth is enabled or disabled.
     - returns:
     
        true, If bluetooth is enabled.
     
        false, If bluetooth is disabled.
     */
    public func isBluetoothEnabled() -> Bool {
        return SipUABluetoothManager.bluetoothEnabled
    }
    
    /**
     Check headphones is connected or not.
     - returns:
     
        true, If headphones is connected.
     
        false, If headphones is not connected.
     */
    public func isHeadphonesConnected() -> Bool {
        return SipUAAudioManager.headphonesConnected
    }
    
    /**
     Check headphones is enabled or disabled.
     - returns:
     
        true, If headphones is enabled.
     
        false, If headphones is disabled.
     */
    public func isHeadphonesEnabled() -> Bool {
        return SipUAAudioManager.headphonesEnabled
    }
    
    // MARK: - Video
    /**
     Set native video window and video preview to linphone for video call.
     - parameters:
        - videoView: the UIView object that will show a remote video view.
        - captureView: the UIView object that will show a capture video view.
     */
    public func createVideoSurface(videoView: UIView?, captureView: UIView?) {
        SipVideoManager.createVideoSurface(videoView: videoView, captureView: captureView)
    }
    
    /**
     Set indicator to show while waiting a first video image.
     - parameters:
        - indicator: an indicator view to show and animate, Do not set anythig for indicator just past the instance.
        - call: a linphone call, Can set to nil (it will get from current call), But in case the current call is nil from pause a call, A [call] parameter is needed.
     */
    public func waitingForVideo(indicator: UIActivityIndicatorView, call: OpaquePointer?) {
        if let currentCall = getCurrentCall() {
            SipVideoManager.waitingForVideo(call: currentCall, viewToShow: indicator)
        } else {
            os_log("Current call is nil : Using input call", log: log_manager_error, type: .error)
            if let aCall = call {
                SipVideoManager.waitingForVideo(call: aCall, viewToShow: indicator)
            } else {
                os_log("Call parameter is nil : Do nothing", log: log_manager_error, type: .error)
                return
            }
        }
    }
    
    /**
     Get all supported video size.
     - returns: an array of SipVideoDefinition.
     */
    public func getSupportedVideoSize() -> Array<SipVideoDefinition> {
        return SipVideoManager.getSupportedVideoSize()
    }
    
    /**
     Check video auto accept policy.
     - returns:
     
        true, If allow to accept video auto.
     
        false, If not allow to accept video auto.
     */
    public func getVideoAutoAccept() -> Bool {
        return SipVideoManager.getVideoAutoAccept()
    }
    
    /**
     Set video auto accept policy.
     - parameters:
        - enable:
     
            true, To enable video auto accept.
     
            false, To disable video auto accept.
     */
    public func setVideoAutoAccept(enable: Bool) {
        SipVideoManager.setVideoAutoAccept(enable: enable)
    }
    
    /**
     Check front or back camera is set for default video call.
     - returns:
     
        true, If the current camera is front camera.
     
        false, If the current camera is back camera.
     */
    public func isFrontCamera() -> Bool {
        return SipVideoManager.isFrontCamera()
    }
    
    /**
     Switch a camera between front and back.
     */
    public func switchCamera() {
        SipVideoManager.switchCamera()
    }
    
    /**
     Check a device is supported video or not.
     - returns:
     
        true, If device support video.
     
        false, If device doesn't support video.
     */
    public func isVideoSupported() -> Bool {
        return SipVideoManager.isVideoSupported()
    }
    
    /* Set default camera (front/back) to linphone */
    internal func setDefaultCamera() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        
        // Get all camera from linphone.
        let camArray: Array<String> = getVideoDevice()
        
        // Compare string.
        // strcmp() - a string compare function.
        // (return 0 if two string is equal, return negative integer if string1 less than string2, return positive integer if string1 greater than string2).
        if (!camArray.isEmpty) {
            for cam in camArray {
                if strcmp(FRONT_CAM_NAME, cam) == 0 {
                    frontCamId = cam
                    os_log("Setting default camera to front camera.", log: log_manager_debug, type: .debug)
                    linphone_core_set_video_device(theLinphoneCore, frontCamId)
                    return
                }
                if strcmp(BACK_CAM_NAME, cam) == 0 {
                    backCamId = cam
                    os_log("Setting default camera to back camera.", log: log_manager_debug, type: .debug)
                    linphone_core_set_video_device(theLinphoneCore, backCamId)
                }
            }
        } else {
            os_log("No camera detect!!", log: log_manager_error, type: .error)
        }
    }
    
    /**
     Pause a video camera by disable a camera with call.
     - parameters:
        - call: a specific call to pause a video.
     */
    public func setVideoPause(call: OpaquePointer) {
        SipVideoManager.setVideoPause(call: call)
    }
    
    /**
     Resume a video camera by enable a camera with call.
     - parameters:
        - call: a specific call to resume a video.
     */
    public func setVideoResume(call: OpaquePointer) {
        SipVideoManager.setVideoResume(call: call)
    }
    
    /**
     Clear all video view.
     */
    public func clearVideoView() {
        SipVideoManager.clearVideoView()
    }
    
    /**
     Get all available camera device.
     - returns: an array of camera device.
     */
    public func getVideoDevice() -> Array<String> {
        return SipVideoManager.getVideoDevice()
    }
    
    /**
     Check a camera enable status from a current call.
     - returns:
     
        true, If camera in current call is enabled.
     
        false, If camera in current call is disabled.
     */
    public func isCameraEnabled() -> Bool {
        return SipVideoManager.isCameraEnabled()
    }
    
    /**
     Enable or disable a camera to a current call and bind or unbind a capture view.
     - parameters:
        - enable:
     
            true, To enable a camera to a current call and bind a capture view.
     
            false, To disable a camera to a current call and unbind a capture view.
     
        - captureView: a capture view to preview a camera as an UIView.
     */
    public func enableCamera(enable: Bool, captureView: UIView?) {
        SipVideoManager.enableCamera(enable: enable, captureView: captureView)
    }
    
    // MARK: - Setting
    /**
     Get the video frame rate, Previously set by setPreferredFramerate().
     - returns: a frame rate.
     */
    public func getPreferredFramerate() -> Float {
        return SipPreferences.getPreferredFramerate()
    }
    
    /**
     Set the video frame rate, Based on the available bandwidth constraints and network conditions.
     There is no warranty that the frame rate be the actual frame rate.
     - parameters:
        - fps: frame rate per second as int.
     */
    public func setPreferredFramerate(fps: Float) {
        SipPreferences.setPreferredFramerate(fps: fps)
    }
    
    /**
     Get the video definition for the stream that is captured and sent to the remote.
     - returns: a SipVideoDefinition.
     */
    public func getPreferredVideoSize() -> SipVideoDefinition {
        return SipPreferences.getPreferredVideoSize()
        
    }
    
    /**
     Set the video size by name.
     - parameters:
        - size: a video size as string, Use getSupportedVideoSize() to see all video size name.
     */
    public func setPreferredVideoSize(size: String) {
        SipPreferences.setPreferredVideoSize(size: size)
    }
    
    /**
     Set incoming call timeout.
     - parameters:
        - seconds: a timing as int.
     */
    public func setIncomingTimeout(seconds: Int) {
        SipPreferences.setIncomingTimeout(seconds: seconds)
    }
    
    /**
     Get incoming call timeout.
     - returns: an incoming call timeout as int.
     */
    public func getIncomingTimeout() -> Int {
        return SipPreferences.getIncomingTimeout()
    }
    
    /**
     Get all audio codecs.
     - returns: an array of SipPayloadType.
     */
    public func getAudioCodecs() -> Array<SipPayloadType> {
        return SipPreferences.getAudioCodecs()
    }
    
    /**
     Get all video codecs.
     - returns: an array of SipPayloadType.
     */
    public func getVideoCodecs() -> Array<SipPayloadType> {
        return SipPreferences.getVideoCodecs()
    }
    
    /**
     Check a specific payload type is enabled or disabled.
     - returns:
     
        true, If a payload type is enabled.
     
        false, If a payload type is disabled.
     */
    public func isPayloadTypeEnabled(pt: SipPayloadType) -> Bool {
        return SipPreferences.isPayloadTypeEnabled(pt: pt)
        
    }
    
    /**
     Set maximum available upload bandwidth, This is IP bandwidth in kbit/s.
     - parameters:
        - uploadBW: the bandwidth in kbits/s, 0 for infinite.
     */
    public func setUploadBandwidth(uploadBW: Int) {
        SipPreferences.setUploadBandwidth(uploadBW: uploadBW)
    }
    
    /**
     Get maximum available upload bandwidth.
     - returns: an upload bandwidth as int.
     */
    public func getUploadBandwidth() -> Int {
        return SipPreferences.getUploadBandwidth()
    }
    
    /**
     Set maximum available download bandwidth, This is IP bandwidth in kbit/s.
     - parameters:
        - downloadBW: the bandwidth in kbits/s, 0 for infinite.
     */
    public func setDownloadBandwidth(downloadBW: Int) {
        SipPreferences.setDownloadBandwidth(downloadBW: downloadBW)
    }
    
    /**
     Get maximum available download bandwidth.
     - returns: an download bandwidth as int.
     */
    public func getDownloadBandwidth() -> Int {
        return SipPreferences.getDownloadBandwidth()
    }
    
    /**
     Enable or disable a specific payload type.
     - parameters:
        - pt: a specific payload type as SipPayloadType.
        - enable:
     
            true, To enable a payload type.
     
            false, To disable a payload type.
     */
    public func enablePayloadType(pt: SipPayloadType, enable: Bool) {
        SipPreferences.enablePayloadType(pt: pt, enable: enable)
    }
    
    
}

// MARK: - Extension for bundle
/* Create exetension by adding compute property for easier to get app name */
extension Bundle {
    public var displayName: String {
        let appName1 = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "nil"
        let appName2 = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "nil"
        let useAppName: String
        if appName1 != "" {
            useAppName = appName1
        } else {
            useAppName = appName2
        }
        return useAppName
    }
}
// MARK: - Extension for int
/* Create exetension by adding compute property for easier to get boolean */
extension Int {
    public var boolValue: Bool {
        if self == 0 {
            return false
        } else {
            return true
        }
    }
}
// MARK: - Extension for Bool
/* Create exetension by adding compute property for easier to get int */
extension Bool {
    public var intValue: Int {
        if self {
            return 1
        } else {
            return 0
        }
    }
}
// MARK: - Extension for string
/* Create exetension by adding functons for easier to get UnsafePointer */
extension String {
    public func stringToUnsafePointerUInt8() -> UnsafePointer<UInt8>? {
        guard let data = self.data(using: String.Encoding.utf8) else { return nil }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        let stream = OutputStream(toBuffer: buffer, capacity: data.count)
        stream.open()
        data.withUnsafeBytes({ (p: UnsafePointer<UInt8>) -> Void in
            stream.write(p, maxLength: data.count)
        })
        stream.close()
        return UnsafePointer<UInt8>(buffer)
    }
    public func stringToUnsafePointerInt8() -> UnsafePointer<Int8>? {
        guard let value = (self as NSString).cString(using: String.Encoding.utf8.rawValue) else { return nil }
        return value
    }
}





