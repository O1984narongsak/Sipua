
import LinphoneModule
import CoreTelephony

// MARK: - Global instance
/**
 Get SipUACallManager instance (a compute property).
 */
internal var SipCallManager: SipUACallManager {
    if SipUACallManager.sipUACallManagerInstance == nil {
        SipUACallManager.sipUACallManagerInstance = SipUACallManager()
    }
    return SipUACallManager.sipUACallManagerInstance!
}

// MARK: - Main class
/**
 SipUACallManager is a class that contain all function about calling.
 */
internal class SipUACallManager {
    
    // MARK: Properties
    // Singleton (The static instance).
    fileprivate static var sipUACallManagerInstance: SipUACallManager?
    
    // MARK: - Call function
    /**
     Make a new call to an username.
     - parameters:
        - to: an username to send invite as string, Example - If full address is sip:John@testserver.com:5060 then [to] parameter should be John.
        - domain: a sip domain as string, Example - [domain] parameter should be testserver.com, Can be nil (it will get from register domain).
        - port: a port number as int, Can be nil (it will get from register port).
        - displayName: a display name as string, Can be nil (it will set to Sip-UA).
        - enableVideo: a video enabled status to send invite with video or audio only.
     */
    public func newOutgoingCall(to: String?, domain: String?, port: Int? = 0, displayName: String?, enableVideo: Bool) {
        
        var sipAddress: OpaquePointer?
        var isLowBandwidthConnection: Bool = false
        var tmpUsername: String = ""
        var tmpDomain: String = ""
        var tmpPort: Int = 0
        
        // Check parameter not nil.
        if to == nil || to == "" {
            os_log("Outgoing username is nil!", log: log_manager_error, type: .error)
            return
        }
        
        let identityTxt = SipUAManager.instance().getIdentityText()
        os_log("Full identity => %@", log: log_manager_debug, type: .debug, identityTxt)
        
        // Get domain, username, port from sip identity for a default setting.
        let identityAddr = linphone_address_new(identityTxt.stringToUnsafePointerInt8())
        tmpDomain = SipUtils.getDomainFromAddress(address: identityAddr!) ?? ""
        tmpUsername = SipUtils.getUsernameFromAddress(address: identityAddr!) ?? ""
        tmpPort = SipUtils.getPortFromAddress(address: identityAddr!) ?? 0
        
        os_log("Username from config => %@", log: log_manager_debug, type: .debug, tmpUsername)
        os_log("Domain from config => %@", log: log_manager_debug, type: .debug, tmpDomain)
        os_log("Port from config => %i", log: log_manager_debug, type: .debug, tmpPort)
        
        // Convert username to sip form.
        sipAddress = SipUtils.normalizeSIPAddress(username: to)
        
        // Get username from sip address.
        let outgoingUsername = String(cString: linphone_address_get_username(sipAddress))
        os_log("Outgoing username => %@", log: log_manager_debug, type: .debug, outgoingUsername)
        
        // Check outgoing username is the same as sip identity or not.
        if outgoingUsername.contains(tmpUsername) {
            os_log("Outgoing username is yourself", log: log_manager_error, type: .error)
            return
        }
        
        // Set display name if empty.
        if displayName == "" || displayName == nil {
            linphone_address_set_display_name(sipAddress, outgoingUsername.stringToUnsafePointerInt8())
            os_log("Display name is nil, Set to the same as username", log: log_manager_debug, type: .debug)
        } else {
            linphone_address_set_display_name(sipAddress, displayName?.stringToUnsafePointerInt8())
        }
        
        // Set domain if empty.
        if domain == "" || domain == nil {
            linphone_address_set_domain(sipAddress, tmpDomain.stringToUnsafePointerInt8())
            os_log("Domain is nil, Set to %@", log: log_manager_debug, type: .debug, tmpDomain)
        } else {
            linphone_address_set_domain(sipAddress, domain?.stringToUnsafePointerInt8())
        }
        
        // Set port if empty.
        if port == 0 || port == nil {
            linphone_address_set_port(sipAddress, (tmpPort as NSNumber).int32Value)
            os_log("Port is nil, Set to %i", log: log_manager_debug, type: .debug, tmpPort)
        } else {
            linphone_address_set_port(sipAddress, (port! as NSNumber).int32Value)
        }
        
        // Check is low bandwidth connection.
        isLowBandwidthConnection = !SipNetworkManager.isHighBandwidthConnection()
        os_log("Low bandwidth connection => %@", log: log_manager_debug, type: .debug, isLowBandwidthConnection ? "true" : "false")
        
        // Check network reachable before invite.
        if (linphone_core_is_network_reachable(LC) as NSNumber).boolValue {
            inviteAddress(address: sipAddress, enableVideo: enableVideo, isLowBandwidth: isLowBandwidthConnection)
            // Unreference address.
            linphone_address_unref(sipAddress)
        } else {
            os_log("Error : No internet connection", log: log_manager_error, type: .error)
            return
        }
    }
    
    /* Send sip invite message */
    private func inviteAddress(address: OpaquePointer?, enableVideo: Bool, isLowBandwidth: Bool) {
        
        // Create linphone call param.
        let callParams = linphone_core_create_call_params(LC, nil)
        
        // Enable video param if need.
        if enableVideo {
            linphone_call_params_enable_video(callParams, UInt8(true.intValue))
            os_log("Invite with video", log: log_manager_debug, type: .debug)
        } else {
            linphone_call_params_enable_video(callParams, UInt8(false.intValue))
            os_log("Invite with audio", log: log_manager_debug, type: .debug)
        }
        
        // Enable low bandwidth and limit audio bandwidth if need.
        if isLowBandwidth {
            linphone_call_params_enable_low_bandwidth(callParams, UInt8(true.intValue))
            linphone_call_params_set_audio_bandwidth_limit(callParams, (40 as NSNumber).int32Value)
            os_log("Enable low bandwidth", log: log_manager_debug, type: .debug)
        } else {
            linphone_call_params_enable_low_bandwidth(callParams, UInt8(false.intValue))
            linphone_call_params_set_audio_bandwidth_limit(callParams, (0 as NSNumber).int32Value)
            os_log("Disable low bandwidth", log: log_manager_debug, type: .debug)
        }
        
        // Send invite with param.
        linphone_core_invite_address_with_params(LC, address, callParams)
        // Unreference a call params.
        linphone_call_params_unref(callParams)
        
    }
    
    /**
     Using for switching between front and back camera.
     */
    public func updateCall() {
        if let currentCall = linphone_core_get_current_call(LC) {
            linphone_call_update(currentCall, nil)
        }
    }
    
    /**
     Switch between voice call and video call.
     - parameters:
        - videoStatus:
     
            true, To send re-invite only audio.
     
            false, To send re-invite audio and video.
     */
    public func disableVideo(videoStatus: Bool) {
        // Check current call.
        if let currentCall = linphone_core_get_current_call(LC) {
            if videoStatus {
                // Re-invite without video.
                reinviteWithoutVideo()
                os_log("Disabled video", log: log_manager_debug, type: .debug)
            } else {
                let remoteParams = linphone_call_get_remote_params(currentCall)
                let isLowBandwidthEnabled = Int(linphone_call_params_low_bandwidth_enabled(remoteParams)).boolValue
                // Check bandwidth for remote call.
                if !isLowBandwidthEnabled {
                     // Re-invite with video.
                    reinviteWithVideo()
                    os_log("Enable video", log: log_manager_debug, type: .debug)
                } else {
                    os_log("Can't start video call : Low bandwidth", log: log_manager_error, type: .error)
                    return
                }
            }
        } else {
            os_log("Call is nil : Can't disabled video", log: log_manager_error, type: .error)
            return
        }
    }
    
    /**
     Send re-invite with video.
     */
    public func reinviteWithVideo() {
        // Check video display enable.
        if !Int(linphone_core_video_display_enabled(LC)).boolValue {
            os_log("Video display is not enable : Can't re-invite with video", log: log_manager_error, type: .error)
            return
        }
        // Check current call.
        if let currentCall = linphone_core_get_current_call(LC) {
            // Get current param and check for video enabled.
            let callParam = linphone_call_get_current_params(currentCall)
            // Check if video already enable.
            let isVideoEnabled = Int(linphone_call_params_video_enabled(callParam)).boolValue
            if isVideoEnabled {
                os_log("Video is already enabled", log: log_manager_debug, type: .debug)
                return
            } else {
                // Create call params from current call.
                let callParams = linphone_core_create_call_params(LC, currentCall)
                // Enable video in call params.
                linphone_call_params_enable_video(callParams, UInt8(true.intValue))
                // Check low bandwidth.
                if !SipNetworkManager.isHighBandwidthConnection() {
                    linphone_call_params_enable_low_bandwidth(callParams, UInt8(true.intValue))
                } else {
                    linphone_call_params_enable_low_bandwidth(callParams, UInt8(false.intValue))
                }
                // Re-invite message.
                linphone_call_update(currentCall, callParams)
                os_log("Re-invite with video", log: log_manager_debug, type: .debug)
                // Unreference a call params.
                linphone_call_params_unref(callParams)
            }
        } else {
            os_log("Call is nil : Can't re-invite with video", log: log_manager_error, type: .error)
            return
        }
    }
    
    /**
     Send re-invite without video.
     */
    public func reinviteWithoutVideo() {
        // Check current call.
        if let currentCall = linphone_core_get_current_call(LC) {
            // Get current param and check for video enabled.
            let callParams = linphone_call_get_current_params(currentCall)
            // Check if video already disable.
            let isVideoEnabled = Int(linphone_call_params_video_enabled(callParams)).boolValue
            if !isVideoEnabled {
                os_log("Video is already disabled", log: log_manager_debug, type: .debug)
                return
            } else {
                // Create call params from current call.
                let callParams = linphone_core_create_call_params(LC, currentCall)
                // Disable video in call params.
                linphone_call_params_enable_video(callParams, UInt8(false.intValue))
                // Check low bandwidth.
                if !SipNetworkManager.isHighBandwidthConnection() {
                    linphone_call_params_enable_low_bandwidth(callParams, UInt8(true.intValue))
                } else {
                    linphone_call_params_enable_low_bandwidth(callParams, UInt8(false.intValue))
                }
                // Re-invite message.
                linphone_call_update(currentCall, callParams)
                os_log("Re-invite with audio", log: log_manager_debug, type: .debug)
                // Unreference a call params.
                linphone_call_params_unref(callParams)
            }
        } else {
            os_log("Call is nil : Can't re-invite with audio", log: log_manager_error, type: .error)
            return
        }
    }
    
    /**
     Update a current call when remote call re-invite with video or audio, Must call in [LinphoneCallUpdatedByRemote] call state.
     */
    public func acceptCallUpdate() {
        // Check current call.
        if let currentCall = linphone_core_get_current_call(LC) {
            // Get remote params.
            let remoteParams = linphone_call_get_remote_params(currentCall)
            // Get local params.
            let localParams = linphone_call_get_current_params(currentCall)
            // Check remote video enable using current call.
            let remoteVideo = Int(linphone_call_params_video_enabled(remoteParams)).boolValue
            // Check local video enable using current call.
            let localVideo = Int(linphone_call_params_video_enabled(localParams)).boolValue
            
            // Create call params from current call.
            let callParams = linphone_core_create_call_params(LC, currentCall)
            if remoteVideo && !localVideo {
                // Set call params for video.
                os_log("Update call to video", log: log_manager_debug, type: .debug)
                linphone_call_params_enable_video(callParams, UInt8(true.intValue))
            } else if !remoteVideo && localVideo {
                // Set call params for audio.
                os_log("Update call to audio", log: log_manager_debug, type: .debug)
                linphone_call_params_enable_video(callParams, UInt8(false.intValue))
            } else {
                os_log("Update call do nothing", log: log_manager_debug, type: .debug)
                os_log("Remote video enabled : %@", log: log_manager_debug, type: .debug, (remoteVideo ? "true" : "false"))
                os_log("Local video enabled : %@", log: log_manager_debug, type: .debug, (localVideo ? "true" : "false"))
            }
            // Check low bandwidth.
            if !SipNetworkManager.isHighBandwidthConnection() {
                linphone_call_params_enable_low_bandwidth(callParams, UInt8(true.intValue))
            } else {
                linphone_call_params_enable_low_bandwidth(callParams, UInt8(false.intValue))
            }
            
            // Using a call params to update current call.
            linphone_call_accept_update(currentCall, callParams)
            // Unreference a call params.
            linphone_call_params_unref(callParams)
        } else {
            os_log("Call is nil", log: log_manager_error, type: .error)
            return
        }
    }
    
    /**
     Update a current call with video disable, Must call in [LinphoneCallUpdatedByRemote] call state.
     */
    public func refreshCall() {
        // Check current call.
        if let currentCall = linphone_core_get_current_call(LC) {
            // Create call params from current call.
            let callParams = linphone_core_create_call_params(LC, currentCall)
            // Disable video in call params.
            linphone_call_params_enable_video(callParams, UInt8(false.intValue))
            // Using a call params to update current call.
            linphone_call_accept_update(currentCall, callParams)
            // Unreference a call params.
            linphone_call_params_unref(callParams)
        } else {
            os_log("Call is nil", log: log_manager_error, type: .error)
            return
        }
    }
    
    /**
     Lock a current call in call state LinphoneCallUpdatedByRemote, Must call in [LinphoneCallUpdatedByRemote] call state.
     - parameters:
        - call: a specific call to defer.
     */
    public func deferCall(call: OpaquePointer) {
        if SipUAManager.instance().getStateOfCall(call: call) == LinphoneCallStateUpdatedByRemote {
            linphone_call_defer_update(call)
        } else {
            os_log("Call is not in state : LinphoneCallUpdatedByRemote", log: log_manager_error, type: .error)
            return
        }
    }
    
    /**
     Get a current call state.
     - returns: a LinphoneCallState.
     */
    public func getStateOfCurrentCall() -> LinphoneCallState {
        if let call = getCurrentCall() {
            // Get state from call.
            return linphone_call_get_state(call)
        } else {
            os_log("Current call is nil : Can't get call state return idle state", log: log_manager_error, type: .error)
        }
        return LinphoneCallStateIdle
    }
    
    /**
     Get a specific call state.
     - parameters:
        - call: a specific call to get state.
     - returns: a LinphoneCallState. Can be nil if linphone call is not exist.
     */
    public func getStateOfCall(call: OpaquePointer?) -> LinphoneCallState {
        // Get state from call.
        if SipUAManager.instance().checkCallExist(call: call) {
            return linphone_call_get_state(call)
        }
        return LinphoneCallStateIdle
    }
    
    /**
     Get a current call, Can be nil if no running call.
     - returns: a current call.
     */
    public func getCurrentCall() -> OpaquePointer? {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return nil
        }
        // Get current call.
        return linphone_core_get_current_call(LC)
    }
    
    /**
     Get a specific call id from call.
     - parameters:
        - call: a specific call to get ID.
     - returns: a call id as string.
     */
    public func getCallCallID(call: OpaquePointer?) -> String {
        if let specificCall = call {
            if let callLog = linphone_call_get_call_log(specificCall) {
                if let callID = linphone_call_log_get_call_id(callLog) {
                    return String(cString: callID)
                } else {
                    os_log("Can't get call id", log: log_manager_error, type: .error)
                }
            } else {
                os_log("Can't get call log", log: log_manager_error, type: .error)
            }
        }
        return ""
    }
    
    /**
     Get all calls.
     - returns: an array of all calls.
     */
    public func getAllCalls() -> Array<OpaquePointer?> {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return []
        }
        // Create array to collect all calls.
        var allCalls: Array<OpaquePointer?> = []
        // Get all calls.
        let callsList = linphone_core_get_calls(LC)
        // Access to the memory of all calls.
        var calls = callsList?.pointee
        
        while calls != nil  {
            // Get raw data from memory of all calls.
            if let callsData = calls?.data {
                // Add call to array.
                allCalls.append(OpaquePointer(callsData))
            }
            // If the next memory of all calls is exist, Move to next call.
            if calls?.next != nil {
                calls = calls?.next.pointee
            } else {
                break
            }
        }
        
        os_log("All calls : %@", log: log_manager_debug, type: .debug, allCalls)
        
        return allCalls
    }
    
    /**
     Get a call direction incoming or outgoing.
     - parameters:
        - call: a call to check direction.
     - returns: a linphone call direction.
     */
    public func getCallDirection(call: OpaquePointer) -> LinphoneCallDir {
        return linphone_call_get_dir(call)
    }
    
    /**
     Accept a call with audio or video.
     - parameters:
        - call: a call to answer.
        - withVideo:
     
            true, If accept call with video enabled.
     
            false, If accept call with audio.
     */
    public func answer(call: OpaquePointer, withVideo: Bool) {
        // Create call param.
        let callParams = linphone_core_create_call_params(LC, call)
        if !SipNetworkManager.isHighBandwidthConnection() {
            os_log("Answer call with low bandwidth mode", log: log_manager_debug, type: .debug)
            linphone_call_params_enable_low_bandwidth(callParams, UInt8(true.intValue))
        } else {
            os_log("Answer call without low bandwidth mode", log: log_manager_debug, type: .debug)
            linphone_call_params_enable_low_bandwidth(callParams, UInt8(false.intValue))
        }
        // Enable video following parameter.
        linphone_call_params_enable_video(callParams, UInt8(withVideo.intValue))
        // Accept call.
        linphone_call_accept_with_params(call, callParams)
        // Unreference a call params.
        linphone_call_params_unref(callParams)
    }
    
    /**
     Decline a call.
     - parameters:
        - call: a call to decline.
     */
    public func decline(call: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_call_decline(call, LinphoneReasonDeclined)
    }
    
    /**
     Decline a call as busy reason, Using to decline a pending incoming call.
     - parameters:
        - call: a specific call to decline as busy reason.
     */
    public func destroyAsBusyCall(call: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_call_decline(call, LinphoneReasonBusy)
    }
    
    /**
     Count a number of call.
     - returns: count all calls as int.
     */
    public func getCallsNumber() -> Int {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return 0
        }
        return Int(linphone_core_get_calls_nb(LC))
    }
    
    /**
     Get a call from call id.
     - parameters:
        - callID: a call id as string.
     - returns: a call.
     */
    public func getCallFromCallID(callID: String?) -> OpaquePointer? {
        guard let callID = callID else {
            os_log("Call id is nil", log: log_manager_error, type: .error)
            return nil
        }
        for call in getAllCalls() where getCallCallID(call: call) == callID {
            os_log("Found call from call id", log: log_manager_debug, type: .debug)
            return call
        }
        os_log("Not found call from call id", log: log_manager_error, type: .error)
        return nil
    }
    
    /**
     Resume a specific call.
     - parameters:
        - call: a specific call to resume.
     */
    public func resumeCall(call: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_call_resume(call)
    }
    
    /**
     Pause a specific call.
     - parameters:
        - call: a specific call to pause.
     */
    public func pauseCall(call: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_call_pause(call)
    }
    
    /**
     Pause all calls.
     */
    public func pauseAllCalls() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_pause_all_calls(LC)
    }
    
    /**
     Terminate a specific call.
     - parameters:
        - call: a specific call to terminate.
     */
    public func terminateCall(call: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_call_terminate(call)
    }
    
    /**
     Terminate all calls.
     */
    public func terminateAllCalls() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_terminate_all_calls(LC)
    }
    
    /**
     Remove a specific call history from address.
     - parameters:
        - address: a specific address to remove a call history. Can be nil it will get call history from identity address instead.
        - historyDetails: a specific sip call history to remove.
     */
    public func removeCallHistory(address: OpaquePointer?, historyDetails: SipCallHistoryDetails) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        // Declare a variable to keep call history.
        var historyList: UnsafeMutablePointer<bctbx_list_t>?
        // Check input parameter
        if address != nil {
            // Get all call history.
            historyList = linphone_core_get_call_history_for_address(LC, address)
            os_log("Get call history from input : %@", log: log_manager_debug, type: .debug, SipUtils.getUsernameFromAddress(address: address!)!)
        } else {
            guard let identity = linphone_core_get_identity(LC) else {
                os_log("Can't get identity, Please set default user to proxy config", log: log_manager_error, type: .error)
                return
            }
            let identityAddr = linphone_address_new(identity)
            // Get all call history.
            historyList = linphone_core_get_call_history_for_address(LC, identityAddr)
            os_log("Get call history from identity : %@", log: log_manager_debug, type: .debug, SipUtils.getUsernameFromAddress(address: identityAddr!)!)
        }
        // Access to the memory of call history.
        var history = historyList?.pointee
        
        while history != nil {
            // Get raw data from memory of call history.
            let historyData = history?.data
            
            // Convert and a value.
            let historyDataPt = OpaquePointer(historyData)
            
            // Get details to check with input.
            let callDirection = linphone_call_log_get_dir(historyDataPt)
            let callStatus = linphone_call_log_get_status(historyDataPt)
            let callDuration = Int(linphone_call_log_get_duration(historyDataPt))
            let isVideoCall = Int(linphone_call_log_video_enabled(historyDataPt)).boolValue
            let callErrorInfo = linphone_error_info_get_reason(linphone_call_log_get_error_info(historyDataPt))
            let callStartDate = TimeInterval(linphone_call_log_get_start_date(historyDataPt))
            if historyDetails.callDirection == callDirection &&
                historyDetails.callStatus == callStatus &&
                historyDetails.callDuration == callDuration &&
                historyDetails.isVideoCall == isVideoCall &&
                historyDetails.callErrorInfo == callErrorInfo &&
                historyDetails.callStartDate == callStartDate {
                // Remove a call history
                linphone_core_remove_call_log(LC, historyDataPt)
            }
            
            // If the next memory of call history is exist, Move to next history.
            if (history?.next) != nil {
                history = history?.next.pointee
            } else {
                break
            }
        }
    }
    
    /**
     Remove all call history from address.
     - parameters:
        - address: a specific address to remove all call history. Can be nil it will get call history from identity address instead.
     */
    public func removeAllCallHistory(address: OpaquePointer?) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        // Declare a variable to keep call history.
        var historyList: UnsafeMutablePointer<bctbx_list_t>?
        // Check input parameter
        if address != nil {
            // Get all call history.
            historyList = linphone_core_get_call_history_for_address(LC, address)
            os_log("Get call history from input : %@", log: log_manager_debug, type: .debug, SipUtils.getUsernameFromAddress(address: address!)!)
        } else {
            guard let identity = linphone_core_get_identity(LC) else {
                os_log("Can't get identity, Please set default user to proxy config", log: log_manager_error, type: .error)
                return
            }
            let identityAddr = linphone_address_new(identity)
            // Get all call history.
            historyList = linphone_core_get_call_history_for_address(LC, identityAddr)
            os_log("Get call history from identity : %@", log: log_manager_debug, type: .debug, SipUtils.getUsernameFromAddress(address: identityAddr!)!)
        }
        // Access to the memory of call history.
        var history = historyList?.pointee
        
        while history != nil {
            // Get raw data from memory of call history.
            let historyData = history?.data
            // Convert a value.
            let historyDataPt = OpaquePointer(historyData)
            // Remove a call history
            linphone_core_remove_call_log(LC, historyDataPt)
            
            // If the next memory of call history is exist, Move to next history.
            if (history?.next) != nil {
                history = history?.next.pointee
            } else {
                break
            }
        }
    }
    
    /**
     Get all call history from address.
     - parameters:
        - address: a specific address to get call history. Can be nil it will get call history from identity address instead.
     - returns: an array of SipCallHistoryDetails.
     */
    public func getAllCallHistory(address: OpaquePointer?) -> Array<SipCallHistoryDetails> {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return []
        }
        // Declare a variable to keep call history.
        var historyList: UnsafeMutablePointer<bctbx_list_t>?
        // Create array to SipCallHistoryDetails.
        var allCallHistory: Array<SipCallHistoryDetails> = []
        // Check input parameter
        if address != nil {
            // Get all call history.
            historyList = linphone_core_get_call_history_for_address(LC, address)
            os_log("Get call history from input : %@", log: log_manager_debug, type: .debug, SipUtils.getUsernameFromAddress(address: address!)!)
        } else {
            guard let identity = linphone_core_get_identity(LC) else {
                os_log("Can't get identity, Please set default user to proxy config", log: log_manager_error, type: .error)
                return []
            }
            let identityAddr = linphone_address_new(identity)
            // Get all call history.
            historyList = linphone_core_get_call_history_for_address(LC, identityAddr)
            os_log("Get call history from identity : %@", log: log_manager_debug, type: .debug, SipUtils.getUsernameFromAddress(address: identityAddr!)!)
        }
        // Access to the memory of call history.
        var history = historyList?.pointee
        
        while history != nil {
            // Create SipCallHistoryDetails.
            var sipCallHistoryDetails = SipCallHistoryDetails()
            // Get raw data from memory of call history.
            let historyData = history?.data
            
            // Convert and add value to SipCallHistoryDetails.
            let historyDataPt = OpaquePointer(historyData)
            // Call direction.
            sipCallHistoryDetails.callDirection = linphone_call_log_get_dir(historyDataPt)
            // Call status.
            sipCallHistoryDetails.callStatus = linphone_call_log_get_status(historyDataPt)
            // Call duration.
            sipCallHistoryDetails.callDuration = Int(linphone_call_log_get_duration(historyDataPt))
            // Call video enable.
            sipCallHistoryDetails.isVideoCall = Int(linphone_call_log_video_enabled(historyDataPt)).boolValue
            // Call error infomation.
            if let errInfo = linphone_call_log_get_error_info(historyDataPt) {
               sipCallHistoryDetails.callErrorInfo = linphone_error_info_get_reason(errInfo)
            }
            // Call start date.
            sipCallHistoryDetails.callStartDate = TimeInterval(linphone_call_log_get_start_date(historyDataPt))
            // Call was in conference.
            sipCallHistoryDetails.callWasConf = Int(linphone_call_log_was_conference(historyDataPt)).boolValue
            // Call remote address
            sipCallHistoryDetails.callRemoteAddr = linphone_call_log_get_remote_address(historyDataPt)
            // Call local address
            sipCallHistoryDetails.callLocalAddr = linphone_call_log_get_local_address(historyDataPt)
            // Call id
            sipCallHistoryDetails.callId = String(cString: linphone_call_log_get_call_id(historyDataPt))
            
            // Add SipCallHistoryDetails to array.
            allCallHistory.append(sipCallHistoryDetails)
            
            // If the next memory of call history is exist, Move to next history.
            if (history?.next) != nil {
                history = history?.next.pointee
            } else {
                break
            }
        }
        
        os_log("All call history : %@", log: log_manager_debug, type: .debug, allCallHistory)
        
        return allCallHistory
    }
    
    /**
     Reset all missed call count.
     */
    public func resetMissedCallCount() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_reset_missed_calls_count(LC)
    }
    
    /**
     Get all missed call count.
     - returns: all missed call count as int.
     */
    public func getAllMissedCallCount() -> Int {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return 0
        }
        return Int(linphone_core_get_missed_calls_count(LC))
    }
    
    /** Count all outgoing init/progress/ringing/early media call.
     - returns: a number of outgoing call as int.
     */
    public func countOutgoingCall() -> Int {
        var count = 0
        for call in getAllCalls() where getStateOfCall(call: call) == LinphoneCallStateOutgoingInit ||
            getStateOfCall(call: call) == LinphoneCallStateOutgoingProgress ||
            getStateOfCall(call: call) == LinphoneCallStateOutgoingRinging ||
            getStateOfCall(call: call) == LinphoneCallStateOutgoingEarlyMedia {
            count += 1
        }
        os_log("Outgoing call numbers : %i", log: log_manager_debug, type: .debug, count)
        return count
    }
    
    /** Count all incoming received/incoming early media call.
     - returns: a number of incoming call as int.
     */
    public func countIncomingCall() -> Int {
        var count = 0
        for call in getAllCalls() where getStateOfCall(call: call) == LinphoneCallStateIncomingReceived || getStateOfCall(call: call) == LinphoneCallStateIncomingEarlyMedia {
            count += 1
        }
        os_log("Incoming call numbers : %i", log: log_manager_debug, type: .debug, count)
        return count
    }
    
    /** Count all running call.
     - returns: a number of running call as int.
     */
    public func countRunningCall() -> Int {
        var count = 0
        for call in getAllCalls() where getStateOfCall(call: call) == LinphoneCallStateStreamsRunning {
            count += 1
        }
        os_log("Running call numbers : %i", log: log_manager_debug, type: .debug, count)
        return count
    }
    
    /** Count all paused/pausing call.
     - returns: a number of paused/pausing call as int.
     */
    public func countPausedCall() -> Int {
        var count = 0
        for call in getAllCalls() where getStateOfCall(call: call) == LinphoneCallStatePaused || getStateOfCall(call: call) == LinphoneCallStatePausing {
            count += 1
        }
        os_log("Paused call numbers : %i", log: log_manager_debug, type: .debug, count)
        return count
    }
    
    /** Count all paused by remote call.
     - returns: a number of paused by remote call as int.
     */
    public func countPausedByRemoteCall() -> Int {
        var count = 0
        for call in getAllCalls() where getStateOfCall(call: call) == LinphoneCallStatePausedByRemote {
            count += 1
        }
        os_log("Paused by remote call numbers : %i", log: log_manager_debug, type: .debug, count)
        return count
    }
    
    /**
     Count the conference size but not include a local call.
     - returns: a conference size as int.
     */
    public func countConferenceCalls() -> Int {
        var conferenceSize = Int(linphone_core_get_conference_size(LC))
        if Int(linphone_core_is_in_conference(LC)).boolValue {
            conferenceSize -= 1
        }
        return conferenceSize
    }
    
    /**
     Reset all missed call count.
     */
    public func resetAllMissedCallCount() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_reset_missed_calls_count(LC)
    }
    
    /**
     Get error reason from call.
     - parameters:
        - call: a call to get error.
     - returns: a call error reason.
     */
    public func getCallErrorReason(call: OpaquePointer) -> LinphoneReason {
        return linphone_error_info_get_reason(linphone_call_get_error_info(call))
    }
    
    /**
     Get reason from call.
     - parameters:
        - call: a call to get reason.
     - returns: a call reason.
     */
    public func getCallReason(call: OpaquePointer) -> LinphoneReason {
        return linphone_call_get_reason(call)
    }
    
    /**
     Get a status of call.
     - parameters:
        - call: a call to get status.
     - returns:
        - a linphone call status.
     */
    public func getCallStatus(call: OpaquePointer) -> LinphoneCallStatus {
        let callLog = linphone_call_get_call_log(call)
        return linphone_call_log_get_status(callLog)
    }
    
    /**
     Transfer a call to a following username.
     - parameters:
        - call: a call that going to transfer.
        - username: an username to transfer, Example - If full address is sip:John@testserver.com:5060 then [username] parameter should be John.
     */
    public func transferCall(call: OpaquePointer, username: String?) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        
        // Check parameter not nil.
        if username == nil || username == "" {
            os_log("Username is nil!", log: log_manager_error, type: .error)
            return
        }
        
        // Get default proxy config.
        let prxCfg = linphone_core_get_default_proxy_config(LC)
        // Convert username to linphone address.
        let tmpAddress = linphone_core_interpret_url(LC, username!.stringToUnsafePointerInt8())
        
        // Check a nil value.
        if prxCfg == nil {
            os_log("No default proxy config", log: log_manager_error, type: .error)
            return
        }
        if tmpAddress == nil {
            os_log("Can't interpret address", log: log_manager_error, type: .error)
            return
        }
        
        // Get identity address from default proxy config. Including display name.
        let identityAddress = String(cString: linphone_address_as_string(linphone_proxy_config_get_identity_address(prxCfg)))
        os_log("Identitiy from proxy config : %@", log: log_manager_debug, type: .debug, identityAddress)
        
        // Get username from convert address.
        let username = String(cString: linphone_address_get_username(tmpAddress))
        os_log("Username : %@", log: log_manager_debug, type: .debug, username)
        
        // Check identity address with convert address to prevent transfering to yourself.
        if identityAddress.contains(username) {
            os_log("Wrong username : You're transfering to yourself", log: log_manager_error, type: .error)
            return
        }
        
        // Transfer a call.
        linphone_call_transfer(call, username.stringToUnsafePointerInt8())
        // Unreference address.
        if tmpAddress != nil {
            linphone_address_unref(tmpAddress)
        }
        
    }
    
    /**
     Attended transfer call, Transfer a call to another running call.
     - parameters:
        - callToTransfer: a call that will be transfer in paused state.
        - destination: a destination call in running state.
     */
    public func transferToAnother(callToTransfer: OpaquePointer, destination: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_call_transfer_to_another(callToTransfer, destination)
    }
    
    /**
     Add all calls into the conference.
     If no conference, a new internal conference context is created and all current calls are added to it.
     */
    public func addAllToConference() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_add_all_to_conference(LC)
    }
    
    /**
     Join the local call to the running conference.
     */
    public func enterConference() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_enter_conference(LC)
    }
    
    /**
     Make the local call leave the running conference.
     */
    public func leaveConference() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_leave_conference(LC)
    }
    
    /** Clear all call from conference including local participant.
     */
    public func clearConference() {
        leaveConference()
        for call in getAllCalls() {
            removeCallFromConference(call: call!)
        }
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
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        if linphone_call_get_conference(call) != nil {
            return true
        } else {
            return false
        }
    }
    
    /**
     Check a local call is part of a conference or not.
     - returns:
     
        true, If the local call is part of a conference.
     
        false, If the local call is not part of a conference.
     */
    public func isInConference() -> Bool {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        return Int(linphone_core_is_in_conference(LC)).boolValue
    }
    
    /**
     Get the number of participant in the running conference.
     The local call is included in the count only if it is in the conference.
     - returns: a conference size as int.
     */
    public func getConferenceSize() -> Int {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return 0
        }
        return Int(linphone_core_get_conference_size(LC))
    }
    
    /**
     Add a call to the conference.
     If no conference, A new internal conference context is created and the participant is added to it.
     - parameters:
        - call: a specific call to add in conference.
     */
    public func addCallToConference(call: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_add_to_conference(LC, call)
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
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_remove_from_conference(LC, call)
    }
    
    /**
     Check the conference is created or not.
     - returns:
     
        true, If conference is created.
     
        false, If conference is not created.
     */
    public func isConferenceCreate() -> Bool {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        if linphone_core_get_conference(LC) != nil {
            return true
        }
        return false
    }
    
    /**
     Terminate the running conference. If it is a local conference,
     All calls inside it will become back separate calls and will be put in [LinphoneCallPaused] state.
     If it is a conference involving a focus server, All calls inside the conference will be terminated.
     */
    public func terminateConference() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        linphone_core_terminate_conference(LC)
    }
    
}
