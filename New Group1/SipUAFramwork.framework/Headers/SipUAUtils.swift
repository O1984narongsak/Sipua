
import LinphoneModule
import CoreTelephony

// MARK: - Global instance
/**
 Get SipUAUtils instance (a compute property).
 */
public var SipUtils: SipUAUtils {
    if SipUAUtils.sipUAUtilsInstance == nil {
        SipUAUtils.sipUAUtilsInstance = SipUAUtils()
    }
    return SipUAUtils.sipUAUtilsInstance!
    
}

// MARK: - Structure platform (Simulator/Device)
/**
 A custom structure of platform that will define a device or simulator.
 - parameters:
    - isSimulator: a closure that return true, If run on device. false, If run on simulator.
 */
public struct Platform {
    // Closure
    public static let isSimulator: Bool = {
        var isSim = false
        #if arch(i386) || arch(x86_64)
            isSim = true
        #endif
        return isSim
    }()
}

// MARK: - Main class
/**
 SipUAUtils is a class that contain all function about sip.
 */
public class SipUAUtils {

    // MARK: Properties
    // Singleton (The static instance).
    fileprivate static var sipUAUtilsInstance: SipUAUtils?
    
    // MARK: - Utils function
    /**
     Checking device model.
     - returns: a device model as a string.
     */
    public func deviceModelIdentifier() -> String {
        if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModelIdentifier
        }
        var systemInfo = utsname()
        uname(&systemInfo) // ignore return value.
        let model = String(bytes: Data(bytes: &systemInfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
        os_log("Device is : %@", model)
        return model
    }
    
    /**
     Convert string username to sip address.
     - parameters:
        - username: an username as a string, Example - If full address is sip:John@testserver.com:5060 then [username] parameter should be John.
     - returns: a linphone address.
     */
    public func normalizeSIPAddress(username: String?) -> OpaquePointer? {
        if let tmpUsername = username, let cfg = linphone_core_get_default_proxy_config(LC) {
            var normalizeAddress: OpaquePointer?
            let usernamePointer = tmpUsername.stringToUnsafePointerInt8()
            if Int(linphone_proxy_config_is_phone_number(cfg, usernamePointer!)).boolValue {
                os_log("Username is phone number", log: log_manager_debug, type: .debug)
                if let normalizeNumber = UnsafePointer(linphone_proxy_config_normalize_phone_number(cfg, usernamePointer!)) {
                     normalizeAddress = linphone_proxy_config_normalize_sip_uri(cfg, normalizeNumber)
                } else {
                    os_log("Normalize phone number error, Invalid input", log: log_manager_error, type: .error)
                    return nil
                }
            } else {
                os_log("Username is not phone number", log: log_manager_debug, type: .debug)
                 normalizeAddress = linphone_proxy_config_normalize_sip_uri(cfg, usernamePointer!)
            }
            if normalizeAddress == nil {
                os_log("Normalize sip address error, Normalize is not successful", log: log_manager_error, type: .error)
                return nil
            }
            return normalizeAddress
        } else {
            os_log("Normalize sip address error, Username is nil or no default proxy config", log: log_manager_error, type: .error)
            return nil
        }
    }
    
    /**
     Convert an address to string.
     - parameters:
        - address: a linphone address to convert.
     - returns: an address as string.
     */
    public func addressToString(address: OpaquePointer) -> String {
        linphone_address_ref(address)
        let addrString = String(cString: linphone_address_as_string(address))
        linphone_address_unref(address)
        return addrString
    }
    
    /**
     Get a remote address without display name.
     - parameters:
        - address: a linphone address to get remote address.
     - returns: a remote address as string.
     */
    public func addressToStringNoDisplayName(address: OpaquePointer) -> String {
        linphone_address_ref(address)
        let addrString = String(cString: linphone_address_as_string_uri_only(address))
        linphone_address_unref(address)
        return addrString
    }
    
    /**
     Extract only domain from address.
     - parameters:
        - address: a linphone address to get domain.
     - returns: a domain as string.
     */
    public func getDomainFromAddress(address: OpaquePointer) -> String? {
        var onlyDomain: String?
        /*
        if address.contains("@") {
            onlyDomain = String(address.split(separator: "@")[1])
        }
        if onlyDomain.contains(":") {
            onlyDomain = String(onlyDomain.split(separator: ":")[0])
        }
        return onlyDomain
        */
        linphone_address_ref(address)
        if let tmpDomain = linphone_address_get_domain(address) {
            onlyDomain = String(cString: tmpDomain)
        }
        linphone_address_unref(address)
        return onlyDomain
    }
    
    /**
     Extract only username from address.
     - parameters:
        - address: a linphone address to get username.
     - returns: an username as string.
     */
    public func getUsernameFromAddress(address: OpaquePointer) -> String? {
        var onlyUsername: String?
        /*
        if address.starts(with: "sip:") {
            let index = address.index(address.startIndex, offsetBy: 4)
            onlyUsername = String(address[index...])
        } else if address.starts(with: "sips:") {
            let index = address.index(address.startIndex, offsetBy: 5)
            onlyUsername = String(address[index...])
        }
        */
        /*
        if address.contains("@") {
            onlyUsername = String(address.split(separator: "@")[0])
        }
        if onlyUsername.contains(":") {
            onlyUsername = String(onlyUsername.split(separator: ":")[1])
        }
        return onlyUsername
        */
        linphone_address_ref(address)
        if let tmpUsername = linphone_address_get_username(address) {
            onlyUsername = String(cString: tmpUsername)
        }
        linphone_address_unref(address)
        return onlyUsername
    }
    
    /**
     Extract only port from address.
     - parameters:
        - address: a linphone address to get port.
     - returns: a port number as int.
     */
    public func getPortFromAddress(address: OpaquePointer) -> Int? {
        var onlyPort: Int?
        /*
        if address.contains("@") {
            var tmpAddress: String = String(address.split(separator: "@")[1])
            tmpAddress = tmpAddress.replacingOccurrences(of: ">", with: "")
            tmpAddress = String(tmpAddress.split(separator: ":")[1])
            if let unwrapPort = Int(tmpAddress) {
                onlyPort = unwrapPort
            }
        }
        return onlyPort
        */
        linphone_address_ref(address)
        onlyPort = Int(linphone_address_get_port(address))
        linphone_address_unref(address)
        return onlyPort
        
    }
    
    /**
     Extract only display name from address.
     - parameters:
        - address: a linphone address to get display name.
     - returns: a display name as string.
     */
    public func getDisplayNameFromAddress(address: OpaquePointer) -> String? {
        var onlyDisplayName: String?
        linphone_address_ref(address)
        if let tmpDisplayname = linphone_address_get_display_name(address) {
            onlyDisplayName = String(cString: tmpDisplayname)
        }
        linphone_address_unref(address)
        return onlyDisplayName
    }
    
    /**
     Convert a linphone call state to string.
     - parameters:
        - callState: a LinphoneCallState.
     - returns: a linphone call state as string.
     */
    public func callStateToString(callState: LinphoneCallState?) -> String {
        if let state = callState {
            return String(cString: linphone_call_state_to_string(state))
        }
        os_log("Error : Can't get call state as string. Call is not exist.", log: log_manager_error, type: .error)
        return "Call is not exist!!"
    }
    
    /**
     Convert a linphone chat message state to string.
     - parameters:
        - messageState: a LinphoneChatMessageState.
     - returns: a linphone chat message state as string.
     */
    public func messageStateToString(messageState: LinphoneChatMessageState) -> String {
        let state = String(cString: linphone_chat_message_state_to_string(messageState))
        os_log("Message state : %@", log: log_manager_debug, type: .debug, state)
        var status: String = ""
        switch messageState {
        case LinphoneChatMessageStateIdle:
            status = "Idle"
        case LinphoneChatMessageStateDelivered:
            status = "Delivered"
        case LinphoneChatMessageStateDisplayed:
            status = "Displayed"
        case LinphoneChatMessageStateInProgress:
            status = "In progress"
        case LinphoneChatMessageStateNotDelivered:
            status = "Not delivered"
        case LinphoneChatMessageStateDeliveredToUser:
            status = "Delivered to user"
        case LinphoneChatMessageStateFileTransferDone:
            status = "File transfer done"
        case LinphoneChatMessageStateFileTransferError:
            status = "File transfer error"
        default:
            status = "Unknown"
        }
        return status
    }
    
    /**
     Calculate call duration from milliseconds.
     - parameters:
        - duration: a call duration seconds as int.
     - returns: a call duration as a string.
     */
    public func durationToString(duration: Int) -> String {
        var result = ""
        var duration = duration
        // 1 hours has 36000 seconds
        // 1 minute has 60 seconds
        // If there are hours
        if (duration / 3600) > 0 {
            // Calculate to hours by using long seconds / 3600
            result = result.appendingFormat("%02i:", duration / 3600)
            // Update duration by removing hours unit (The remainder from 1 hour = 3600 seconds)
            duration = duration % 3600
        }
        // Return string format as hours, minutes and seconds
        result = result.appendingFormat("%02i:%02i", duration / 60, duration % 60)
        
        return result
    }
    
    /**
     Convert a time from message to a date format.
     - parameters:
        - time: a time_t type to convert.
        - dateFormat: a date format. If nil it will use default format (The same day - HH:mm | Not the same day - dd/MM - HH:mm)
     - returns: a string of date format.
     */
    public func timeToString(time: TimeInterval, dateFormat: String?) -> String {
        
        var format: String = ""
        
        let todayDate = Date()
        let inputDate = (time == 0) ? todayDate : Date(timeIntervalSince1970: time)
        
        let todayDateComponent = Calendar.current.dateComponents([.day,.month,.year], from: todayDate)
        let inputDateComponent = Calendar.current.dateComponents([.day,.month,.year], from: inputDate)
        
        let sameYear = (todayDateComponent.year == inputDateComponent.year)
        let sameMonth = (sameYear && (todayDateComponent.month == inputDateComponent.month))
        let sameDay = (sameMonth && (todayDateComponent.day == inputDateComponent.day))
        
        if dateFormat == nil {
            if sameDay {
                format = "HH:mm"
            } else {
                format = "dd/MM - HH:mm"
            }
        } else {
            format = dateFormat!
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: inputDate)
        
    }
    
    /**
     Convert a time type TimeInterval to string.
     - parameters:
        - interval: a time type TimeInterval to convert.
     - returns: a string of time in seconds.
     */
    public func intervalToString(interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = .second
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: interval)!
    }
    
    /**
     Convert a linphone call status to string.
     - parameters:
        - callStatus: a linphone call status to convert.
     - returns: a call status as string.
     */
    public func callStatusToString(callStatus: LinphoneCallStatus) -> String {
        var strStatus = ""
        switch callStatus {
        case LinphoneCallSuccess:
            strStatus = "Success Call"
        case LinphoneCallAborted:
            strStatus = "Aborted Call"
        case LinphoneCallMissed:
            strStatus = "Missed Call"
        case LinphoneCallDeclined:
            strStatus = "Declined Call"
        case LinphoneCallEarlyAborted:
            strStatus = "Early Aborted Call"
        case LinphoneCallAcceptedElsewhere:
            strStatus = "Accepted Else Where Call"
        default:
            strStatus = "Declined Else Where Call"
        }
        return strStatus
    }
    
    /**
     Convert a linphone call direction to string.
     - parameters:
        - callDirection: a linphone call direction to convert.
     - returns: a call direction as string.
     */
    public func callDirectionToString(callDirection: LinphoneCallDir) -> String {
        var strDirection = ""
        switch callDirection {
        case LinphoneCallIncoming:
            strDirection = "Incoming Call"
        case LinphoneCallOutgoing:
            strDirection = "Outgoing Call"
        default:
            strDirection = "Unknown Call Direction"
        }
        return strDirection
    }
    
    /**
     Convert a linphone reason to string.
     - parameters:
        - reason: a linphone reason to convert.
     - returns: a reason as string.
     */
    public func reasonToString(reason: LinphoneReason) -> String {
        var strReason = ""
        switch reason {
        case LinphoneReasonBusy:
            strReason = "Busy Reason"
        case LinphoneReasonGone:
            strReason = "Gone Reason"
        case LinphoneReasonIOError:
            strReason = "IO Error Reason"
        case LinphoneReasonNoMatch:
            strReason = "No Match Reason"
        case LinphoneReasonNone:
            strReason = "None Reason"
        case LinphoneReasonDeclined:
            strReason = "Declined Reason"
        case LinphoneReasonNotFound:
            strReason = "Not Found Reason"
        case LinphoneReasonForbidden:
            strReason = "Forbidden Reason"
        case LinphoneReasonBadGateway:
            strReason = "Bad Gateway Reason"
        case LinphoneReasonNoResponse:
            strReason = "No Response Reason"
        case LinphoneReasonNotAnswered:
            strReason = "Not Answered Reason"
        case LinphoneReasonDoNotDisturb:
            strReason = "Do Not Disturb Reason"
        case LinphoneReasonUnauthorized:
            strReason = "Unauthorized Reason"
        case LinphoneReasonNotAcceptable:
            strReason = "Not Acceptable Reason"
        case LinphoneReasonServerTimeout:
            strReason = "Server Timeout Reason"
        case LinphoneReasonNotImplemented:
            strReason = "Not Implemented Reason"
        case LinphoneReasonMovedPermanently:
            strReason = "Moved Permanently Reason"
        case LinphoneReasonAddressIncomplete:
            strReason = "Address Incomplete Reason"
        case LinphoneReasonUnsupportedContent:
            strReason = "Unsupported Content Reason"
        case LinphoneReasonTemporarilyUnavailable:
            strReason = "Temporarily Unavailable Reason"
        default:
            strReason = "Unknown Reason"
        }
        return strReason
    }
    
    /**
     Get an identity username from a specifig config.
     - parameters:
        - config: a linphone configuration.
     - returns: an identity username as string.
     */
    public func getIdentityUsernameFromConfig(config: OpaquePointer) -> String? {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return nil
        }
        let identityAddr = linphone_proxy_config_get_identity_address(config)
        linphone_address_ref(identityAddr)
        let identityUsernameStr = String(cString: linphone_address_get_username(identityAddr))
        linphone_address_unref(identityAddr)
        return identityUsernameStr
    }
    
    /**
     Get an identity domain from a specifig config.
     - parameters:
        - config: a linphone configuration.
     - returns: an identity domain as string.
     */
    public func getIdentityDomainFromConfig(config: OpaquePointer) -> String? {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return nil
        }
        let identityAddr = linphone_proxy_config_get_identity_address(config)
        linphone_address_ref(identityAddr)
        let identityDomainStr = String(cString: linphone_address_get_domain(identityAddr))
        linphone_address_unref(identityAddr)
        return identityDomainStr
    }
    
    /**
     Get an identity port from a specifig config.
     - parameters:
        - config: a linphone configuration.
     - returns: an identity port as int.
     */
    public func getIdentityPortFromConfig(config: OpaquePointer) -> Int? {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return nil
        }
        let identityAddr = linphone_proxy_config_get_identity_address(config)
        linphone_address_ref(identityAddr)
        let identityPortStr = Int(linphone_address_get_port(identityAddr))
        linphone_address_unref(identityAddr)
        return identityPortStr
    }
    
    /**
     Get an enable register status from a specifig config.
     - parameters:
        - config: a linphone configuration.
     - returns:
     
        true, If a config is enabled register.
     
        false, If a config is not enabled register.
     */
    public func getRegisterEnabledFromConfig(config: OpaquePointer) -> Bool {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        return Int(linphone_proxy_config_register_enabled(config)).boolValue
    }
    
    /**
     Check a default config status from a specifig config.
     - parameters:
        - config: a linphone configuration.
     - returns:
     
        true, If a config is a default config.
     
        false, If a config is not a default config.
     */
    public func getDefaultSetStatusFromConfig(config: OpaquePointer) -> Bool {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        if let defaultPrxCfg = linphone_core_get_default_proxy_config(LC) {
            if config == defaultPrxCfg {
                return true
            }
        } else {
            os_log("No default proxy config set", log: log_manager_error, type: .error)
        }
        return false
    }
    
    /**
     Get a username from a specifig auth info.
     - parameters:
        - authInfo: a linphone authentication infomation.
     - returns: an username as string.
     */
    public func getUsernameFromAuthInfo(authInfo: OpaquePointer) -> String? {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return nil
        }
        return String(cString: linphone_auth_info_get_username(authInfo))
    }
    
    /**
     Get a domain from a specifig auth info.
     - parameters:
        - authInfo: a linphone authentication infomation.
     - returns: a domain as string.
     */
    public func getDomainFromAuthInfo(authInfo: OpaquePointer) -> String? {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return nil
        }
        return String(cString: linphone_auth_info_get_domain(authInfo))
    }
    
}
