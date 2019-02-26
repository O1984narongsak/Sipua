//
//  CallKitProvider.swift
//  SipUa
//
//  Created by NLDeviOS on 18/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import CallKit
import SipUAFramwork
import LinphoneModule
import AVFoundation
import CoreTelephony

class CallKitProvider: NSObject, CXProviderDelegate {
    
    static var callKitConfiguration: CXProviderConfiguration {
        let providerConfiguration  = CXProviderConfiguration(localizedName: Bundle.main.displayName)
        providerConfiguration.supportsVideo = false
        providerConfiguration.ringtoneSound = "ringtone.wav"
        providerConfiguration.supportedHandleTypes = [.generic]
        providerConfiguration.maximumCallGroups = 2
        providerConfiguration.maximumCallsPerCallGroup = 1
        if let iconMask = UIImage(named: "IconMask") {
            providerConfiguration.iconTemplateImageData = iconMask.pngData()
        }
        return providerConfiguration
    }
    
    var callProvider: CXProvider
    var pendingCall: OpaquePointer?
    var isVideo: Bool = false
    
    // MARK: - Initial class
    override init() {
        os_log("CallKit : Provider initialized", log: log_app_debug, type: .debug)
        callProvider = CXProvider(configuration: CallKitProvider.callKitConfiguration)
        super.init()
        callProvider.setDelegate(self, queue: nil)
    }
    
    // MARK: - Received call, CallProvider call this function
    func receiveCall(call: OpaquePointer, uuid: UUID, completion: ((Error?)->Void)?) {
        os_log("========== CallKit : Receive call ==========", log: log_app_debug, type: .debug)
        let update = CXCallUpdate()
        let isVideo = sipUAManager.isRemoteVideoEnabled(call: call)
        update.hasVideo = isVideo
        let callName = (sipUAManager.getRemoteDisplayName(call: call) ?? sipUAManager.getRemoteUsername(call: call)) ?? "Unknown"
        os_log("CallKit : Receive call from : %@", log: log_app_debug, type: .debug, callName)
        update.remoteHandle = CXHandle(type: .generic, value: callName)
        update.supportsGrouping = true
        update.supportsUngrouping = true
        update.supportsHolding = true
        // This function will show phone native UI
        callProvider.reportNewIncomingCall(with: uuid, update: update) { (error: Error?) in
            // If error from receiving call
            if error != nil {
                let cError = error as! CXErrorCodeIncomingCallError
                var errorStr = ""
                switch cError.code {
                case .callUUIDAlreadyExists:
                    errorStr = "Call UUID already exist"
                case .filteredByBlockList:
                    errorStr = "Call is in block list"
                case .filteredByDoNotDisturb:
                    errorStr = "Do not disturb is enabled"
                case .unentitled:
                    errorStr = "Unentitled"
                case .unknown:
                    errorStr = "Unknown"
                }
                os_log("CallKit : Report incoming call error : %@", log: log_app_error, type: .error, errorStr)
                os_log("CallKit : Decline call as busy", log: log_app_error, type: .error)
                sipUAManager.destroyAsBusyCall(call: call)
                Controller.removeControllerCall(call: call)
            } else {
                // Add call manually when received an incoming call
                Controller.addControllerCall(call: call, isVideo: isVideo, uuid: uuid, isOutgoing: false)
            }
            completion?(error)
        }
    }
    
    // MARK: - Update call, CallProvider call this function
    func updateCall(call: OpaquePointer, uuid: UUID) {
        os_log("========== CallKit : Update call ==========", log: log_app_debug, type: .debug)
        let update = CXCallUpdate()
        update.hasVideo = sipUAManager.isRemoteVideoEnabled(call: call)
        let callName = (sipUAManager.getRemoteDisplayName(call: call) ?? sipUAManager.getRemoteUsername(call: call)) ?? "Unknown"
        os_log("CallKit : Update call to : %@", log: log_app_debug, type: .debug, callName)
        update.remoteHandle = CXHandle(type: .generic, value: callName)
        update.supportsGrouping = true
        update.supportsUngrouping = true
        update.supportsHolding = true
        callProvider.reportCall(with: uuid, updated: update)
    }
    
    // MARK: - Provider did reset, CallProvider call this function automatically
    func providerDidReset(_ provider: CXProvider) {
        os_log("========== CallKit : Provider reset ==========", log: log_app_debug, type: .debug)
        sipUAManager.terminateAllCalls()
        //Controller.clearCalls()
    }
    
    // MARK: - Config audio session, Self call this function
    public func configAudioSession(audioSession: AVAudioSession) {
        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.default, options: AVAudioSession.CategoryOptions.allowBluetooth)
        } catch {
            os_log("CallKit : Can't set audio session category : %@", log: log_app_error, type: .error, error.localizedDescription)
        }
        
        do {
            try audioSession.setMode(AVAudioSession.Mode.voiceChat)
        } catch {
            os_log("CallKit : Can't set audio session mode : %@", log: log_app_error, type: .error, error.localizedDescription)
        }
        
        let sampleRate: Double = 44100.0
        do {
            try audioSession.setPreferredSampleRate(sampleRate)
        } catch {
            os_log("CallKit : Can't set audio session sample rate : %@", log: log_app_error, type: .error, error.localizedDescription)
        }
    }
    
    // MARK: - Start call, CallController call this function
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        os_log("========== CallKit : Start call action ==========", log: log_app_debug, type: .debug)
        
        guard let call = Controller.getCallKitCall(uuid: action.callUUID) else {
            os_log("CallKit : Start call uuid is not found", log: log_app_error, type: .error)
            return
        }
        
        // Restart audio unit
        configAudioSession(audioSession: AVAudioSession.sharedInstance())
        // Complete action
        action.fulfill()
        
        // Set call to use in active audio session
        pendingCall = call.call
        isVideo = call.isVideo
        os_log("CallKit : Pending call id is updated : %@ (%@) : CXStartCallAction", log: log_app_debug, type: .debug, call.callID, call.callName)
        
        // Update CallKit call id
        call.callID = sipUAManager.getCallCallID(call: call.call)
        
    }
    
    // MARK: - Answer call, Native UI call this function
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        os_log("========== CallKit : Answer call action ==========", log: log_app_debug, type: .debug)
        
        guard let call =  Controller.getCallKitCall(uuid: action.callUUID), sipUAManager.checkCallExist(call: call.call) else {
            os_log("CallKit : Answer call uuid is not found or call doesn't exist", log: log_app_error, type: .error)
            return
        }
        
        // Restart audio unit
        configAudioSession(audioSession: AVAudioSession.sharedInstance())
        // Complete action
        action.fulfill()
        
        // Set call to use in active audio session
        pendingCall = call.call
        isVideo = call.isVideo
        os_log("CallKit : Pending call id is updated : %@ (%@) : CXAnswerCallAction", log: log_app_debug, type: .debug, call.callID, call.callName)
        
        // Load calling view
//        if let callingView = CallingView.viewControllerInstance() {
//            if isVideo {
//                os_log("CallKit : Load audio call view", log: log_app_debug, type: .debug)
//                callingView.toClass = AppView.ClassName.VideoCall
//                callingView.xibName = AppView.XibName.VideoCall
//                callingView.videoBeforePause = true
//            } else {
//                os_log("CallKit : Load video call view", log: log_app_debug, type: .debug)
//                callingView.toClass = AppView.ClassName.AudioCall
//                callingView.xibName = AppView.XibName.AudioCall
//                callingView.videoBeforePause = false
//            }
//            callingView.refreshLoadContentView()
//        }
        
    }
    
    // MARK: - End call, CallController and Native UI call this function
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        os_log("========== CallKit : End call action ==========", log: log_app_debug, type: .debug)
        
        // Complete action
        action.fulfill()
        
        // GSM call and VoIP call. User tap (End & Answer) button
        // ======================================================
        if Controller.getGSMCalls().count != 0 {
            os_log("CallKit : GSM call happen", log: log_app_debug, type: .debug)
            // Terminate conference if happen
            if sipUAManager.isConferenceCreate() || sipUAManager.getConferenceSize() != 0 {
                os_log("CallKit : Terminate conference", log: log_app_debug, type: .debug)
                sipUAManager.terminateConference()
            }
            // We need to terminate all VoIP call, if not. GSM call will be pause and the remain VoIP call will connected we don't want that
            // Terminate all VoIP call if accept GSM call and hangup VoIP call
            if sipUAManager.getAllCalls().count != 0 {
                os_log("CallKit : Terminate all call", log: log_app_debug, type: .debug)
                sipUAManager.terminateAllCalls()
                //Controller.clearCalls()
            }
        }
        // ======================================================
        
        os_log("CallKit : Normal hangup", log: log_app_debug, type: .debug)
        if let callKitCall = Controller.getCallKitCall(uuid: action.callUUID) {
            if sipUAManager.checkCallExist(call: callKitCall.call) {
                os_log("CallKit : Call still exist. Terminate call id : %@ (%@)", log: log_app_debug, type: .debug, callKitCall.callID, callKitCall.callName)
                // If native UI decline
                sipUAManager.terminateCall(call: callKitCall.call)
            }
            //Controller.removeCall(call: callKitCall.call)
        }
        
        os_log("CallKit : All calls in controller : %i", log: log_app_debug, type: .debug, Controller.getControllerCalls().count)
        
    }
    
    // MARK: - Pause call, CallController call this function
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        os_log("========== CallKit : Hold call action ==========", log: log_app_debug, type: .debug)
        
        // Complete action
        action.fulfill()
        
        // GSM call and VoIP call. User tap (Hold & Answer) button
        // =======================================================
        if Controller.getGSMCalls().count != 0 && action.isOnHold {
            os_log("CallKit : GSM call happen, Action is hold VoIP call", log: log_app_debug, type: .debug)
            // Leave conference if happen
            if sipUAManager.isConferenceCreate() || sipUAManager.getConferenceSize() != 0 {
                os_log("CallKit : Leave conference", log: log_app_debug, type: .debug)
                sipUAManager.leaveConference()
            }
            // We need to pause all VoIP calls, if not. GSM call will be pause and the remain VoIP call will connected we don't want that
            // Pause all VoIP calls if accept GSM call and pause VoIP call
            if sipUAManager.getAllCalls().count != 0 {
                os_log("CallKit : Pause all calls", log: log_app_debug, type: .debug)
                sipUAManager.pauseAllCalls()
            }
//            if let callingView = CallingView.viewControllerInstance() {
//                // Update leave or enter conference view
//                callingView.updatePauseConferenceStatus()
//                // refresh call cell in table
//                callingView.refreshPauseCallList()
//                callingView.refreshConferenceCallList()
//            }
            return
        }
        // =======================================================
        
        guard let call =  Controller.getCallKitCall(uuid: action.callUUID) else {
            os_log("CallKit : Hold call uuid is not found", log: log_app_error, type: .error)
            return
        }
        
        let callState = sipUAManager.getStateOfCall(call: call.call)
        os_log("CallKit : %@ , Name : %@ , Call id : %@", log: log_app_debug, type: .debug, action.isOnHold ? "Hold" : "Unhold", call.callName, call.callID)
        os_log("CallKit : Call state : %@", log: log_app_debug, type: .debug, SipUtils.callStateToString(callState: callState))
        
        // Pause call
        if action.isOnHold {
            os_log("CallKit : Pause normal call", log: log_app_debug, type: .debug)
            sipUAManager.pauseCall(call: call.call)
            // Resume call
        } else {
            // In case GSM call happen and conference room is running then pause all call and make local leave from conference room
            // from a logic above. If user wants resume VoIP call and conference is created
            if sipUAManager.isConferenceCreate() && sipUAManager.getConferenceSize() > 1 {
                // Make local enter conference
                os_log("CallKit : Make local enter conference and resume all paused call that used to enter conference", log: log_app_debug, type: .debug)
                sipUAManager.enterConference()
                // Resume all paused calls that used to enter conference
                for call in sipUAManager.getAllCalls() where sipUAManager.isCallInConference(call: call!) {
                    sipUAManager.resumeCall(call: call!)
                }
//                if let callingView = CallingView.viewControllerInstance() {
//                    // Update leave or enter conference view
//                    callingView.updatePauseConferenceStatus()
//                    // refresh call cell in table
//                    callingView.refreshPauseCallList()
//                    callingView.refreshConferenceCallList()
//                }
            } else {
                os_log("CallKit : Resume normal call", log: log_app_debug, type: .debug)
                os_log("CallKit : Refresh audio session", log: log_app_debug, type: .debug)
                configAudioSession(audioSession: AVAudioSession.sharedInstance())
                
                // Update pending call to active audio session
                pendingCall = call.call
                isVideo = call.isVideo
                
                let callName = (sipUAManager.getRemoteDisplayName(call: call.call) ?? sipUAManager.getRemoteUsername(call: call.call)) ?? "Unknown"
                os_log("CallKit : Pending call id is updated : %@ (%@) : CXSetHeldCallAction", log: log_app_debug, type: .debug, call.callID, callName)
            }
        }
        
    }
    
    // MARK: - Muted call, CallController call this function
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        os_log("========== CallKit : Muted call action ==========", log: log_app_debug, type: .debug)
        action.fulfill()
        
        os_log("CallKit : Muted status : %@", log: log_app_debug, type: .debug, action.isMuted ? "true" : "false")
        if action.isMuted {
            sipUAManager.muteMic(status: true)
        } else {
            sipUAManager.muteMic(status: false)
        }
        
    }
    
    // MARK: - Activate audio session
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        os_log("========== CallKit : Activate audio session ==========", log: log_app_debug, type: .debug)
        guard let call = pendingCall, sipUAManager.checkCallExist(call: call) else {
            os_log("CallKit : Pending call is nil or doesn't exist", log: log_app_error, type: .error)
            return
        }
        
        let callName = (sipUAManager.getRemoteDisplayName(call: call) ?? sipUAManager.getRemoteUsername(call: call)) ?? "Unknown"
        os_log("CallKit : Pending call id : %@ (%@) : didActivate audioSession", log: log_app_debug, type: .debug, sipUAManager.getCallCallID(call: call), callName)
        
        let state = sipUAManager.getStateOfCall(call: call)
        switch state {
        case LinphoneCallStateIncomingReceived:
            os_log("CallKit : Received call state", log: log_app_debug, type: .debug)
            os_log("CallKit : Accept call with %@", log: log_app_debug, type: .debug, isVideo ? "video" : "audio")
            if isVideo && sipUAManager.getVideoAutoAccept() {
                os_log("CallKit : Video auto accept policy is allow, Can answer with video", log: log_app_debug, type: .debug)
                sipUAManager.answer(call: call, withVideo: true)
            } else {
                os_log("CallKit : Video auto accept policy is not allow, Answer call with audio only", log: log_app_debug, type: .debug)
                sipUAManager.answer(call: call, withVideo: false)
            }
        case LinphoneCallStatePaused, LinphoneCallStatePausing:
            os_log("CallKit : Paused call state", log: log_app_debug, type: .debug)
            os_log("CallKit : Resume call", log: log_app_debug, type: .debug)
            sipUAManager.resumeCall(call: call)
        case LinphoneCallStateStreamsRunning:
            os_log("CallKit : Running call state", log: log_app_debug, type: .debug)
        default:
            break
        }
        
        os_log("CallKit : Set pending call to nil after activated audio", log: log_app_debug, type: .debug)
        pendingCall = nil
        isVideo = false
        
    }
    
    // MARK: - Deactivate audio session
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        os_log("========== CallKit : Deactivate audio session ==========", log: log_app_debug, type: .debug)
        
        os_log("CallKit : Set pending call to nil after deactivated audio", log: log_app_debug, type: .debug)
        pendingCall = nil
        isVideo = false
        
    }
    
    // MARK: - Checking VoIP call to show incoming call view or not showing in CallingView
    func shouldShowIncomingCallView() -> Bool {
        if sipUAManager.getCallsNumber() > 1 {
            os_log("CallKit : Call number > 1", log: log_app_debug, type: .debug)
            var count = 0
            for call in sipUAManager.getAllCalls() where sipUAManager.getCallDirection(call: call!) == LinphoneCallIncoming {
                count += 1
            }
            if count == 0 {
                os_log("CallKit : Incoming call count = 0 ", log: log_app_debug, type: .debug)
                return false
            } else {
                os_log("CallKit : Incoming call count != 0 ", log: log_app_debug, type: .debug)
                return true
            }
        }
        os_log("CallKit : Call number <= 1", log: log_app_debug, type: .debug)
        return false
    }
    
}

