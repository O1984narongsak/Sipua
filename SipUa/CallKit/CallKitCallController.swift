//
//  CallKitCallController.swift
//  SipUa
//
//  Created by NLDeviOS on 18/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import CallKit
import SipUAFramwork
import LinphoneModule

class CallKitCall {
    var call: OpaquePointer
    var callID: String
    var callName: String
    var uuid: UUID
    var isOutgoing: Bool
    var isConnected: Bool
    var isVideo: Bool
    
    init(call: OpaquePointer, isVideo: Bool, uuid: UUID, isOutgoing: Bool) {
        self.call = call
        self.callID = sipUAManager.getCallCallID(call: call)
        let callName = (sipUAManager.getRemoteDisplayName(call: call) ?? sipUAManager.getRemoteUsername(call: call)) ?? "Unknown"
        os_log("CallKit : Call name is set to : %@", log: log_app_debug, type: .debug, callName)
        self.callName = callName
        self.uuid = uuid
        self.isOutgoing = isOutgoing
        self.isConnected = false
        self.isVideo = isVideo
    }
}

class CallKitCallController: NSObject, CXCallObserverDelegate {
    
    private let callController: CXCallController
    private var controllerCalls: Array<CallKitCall>
    private var gsmCalls: Array<CXCall>
    
    override init() {
        os_log("CallKit : Call controller initialized", log: log_app_debug, type: .debug)
        callController = CXCallController()
        controllerCalls = [CallKitCall]()
        gsmCalls = [CXCall]()
        super.init()
        callController.callObserver.setDelegate(self, queue: nil)
    }
    
    func getControllerCalls() -> Array<CallKitCall> {
        return controllerCalls
    }
    
    func getGSMCalls() -> Array<CXCall> {
        return gsmCalls
    }
    
    func startCall(uuid: UUID, handle: String, call: OpaquePointer, isVideo: Bool, isOutgoing: Bool) {
        os_log("CallKit : Add call to controller", log: log_app_debug, type: .debug)
        addControllerCall(call: call, isVideo: isVideo, uuid: uuid, isOutgoing: isOutgoing)
        os_log("CallKit : Request start call action", log: log_app_debug, type: .debug)
        let handle = CXHandle(type: .generic, value: handle)
        let action = CXStartCallAction(call: uuid, handle: handle)
        action.isVideo = isVideo
        let transaction = CXTransaction(action: action)
        requestTransaction(transaction: transaction)
    }
    
    func endCall(uuid: UUID) {
        os_log("CallKit : Request end call action", log: log_app_debug, type: .debug)
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        requestTransaction(transaction: transaction)
    }
    
    func answerCall(uuid: UUID) {
        os_log("CallKit : Request answer call action", log: log_app_debug, type: .debug)
        let action = CXAnswerCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        requestTransaction(transaction: transaction)
    }
    
    func holdCall(uuid: UUID, onHold: Bool) {
        os_log("CallKit : Request hold call action", log: log_app_debug, type: .debug)
        let action = CXSetHeldCallAction(call: uuid, onHold: onHold)
        let transaction = CXTransaction(action: action)
        requestTransaction(transaction: transaction)
    }
    
    func muteCall(uuid: UUID, onMute: Bool) {
        os_log("CallKit : Request mute call action", log: log_app_debug, type: .debug)
        let action = CXSetMutedCallAction(call: uuid, muted: onMute)
        let transaction = CXTransaction(action: action)
        requestTransaction(transaction: transaction)
    }
    
    private func requestTransaction(transaction: CXTransaction) {
        callController.request(transaction) { (error) in
            if error != nil {
                let cError = error as! CXErrorCodeRequestTransactionError
                var errorStr = ""
                switch cError.code {
                case .callUUIDAlreadyExists:
                    errorStr = "Call UUID already exist"
                case .emptyTransaction:
                    errorStr = "Empty transaction"
                case .invalidAction:
                    errorStr = "Invalid action"
                case .maximumCallGroupsReached:
                    errorStr = "Maximun call groups reached"
                case .unentitled:
                    errorStr = "Unentitled"
                case .unknown:
                    errorStr = "Unknown"
                case .unknownCallProvider:
                    errorStr = "Unknown call provider"
                case .unknownCallUUID:
                    errorStr = "Unknown call UUID"
                }
                os_log("CallKit : Call request transaction error : %@", log: log_app_error, type: .error, errorStr)
            } else {
                os_log("CallKit : Call request successful", log: log_app_debug, type: .debug)
            }
        }
    }
    
    func addControllerCall(call: OpaquePointer, isVideo: Bool, uuid: UUID, isOutgoing: Bool) {
        var isAdd: Bool = false
        for aCall in controllerCalls where aCall.call == call {
            isAdd = true
        }
        if !isAdd {
            os_log("CallKit : Call is not add yet : Add it", log: log_app_debug, type: .debug)
            controllerCalls.append(CallKitCall(call: call, isVideo: isVideo, uuid: uuid, isOutgoing: isOutgoing))
        } else {
            os_log("CallKit : Call is already added : Do nothing", log: log_app_debug, type: .debug)
            return
        }
    }
    
    func addGSMCall(call: CXCall) {
        var isAdd: Bool = false
        for aCall in gsmCalls where aCall.uuid == call.uuid {
            isAdd = true
        }
        if !isAdd {
            os_log("CallKit : GSM call is not add yet : Add it", log: log_app_debug, type: .debug)
            gsmCalls.append(call)
        } else {
            os_log("CallKit : GSM call is already added : Do nothing", log: log_app_debug, type: .debug)
            return
        }
    }
    
    func removeControllerCall(call: OpaquePointer) {
        for (index,data) in controllerCalls.enumerated() where data.call == call {
            controllerCalls.remove(at: index)
            os_log("CallKit : Remove call %@ (%@) from controller", log: log_app_debug, type: .debug, data.callID, data.callName)
            return
        }
        os_log("CallKit : Not found call to remove", log: log_app_debug, type: .debug)
    }
    
    func removeGSMCall(call: CXCall) {
        for (index,data) in gsmCalls.enumerated() where data.uuid == call.uuid {
            gsmCalls.remove(at: index)
            os_log("CallKit : Remove gsm call [%@] from controller", log: log_app_debug, type: .debug, data.uuid.uuidString)
            return
        }
        os_log("CallKit : Not found gsm call to remove", log: log_app_debug, type: .debug)
    }
    
    func clearCalls() {
        controllerCalls.removeAll()
        os_log("CallKit : Clear all calls", log: log_app_debug, type: .debug)
    }
    
    func getUUID(call: OpaquePointer) -> UUID? {
        for aCall in controllerCalls where aCall.call == call {
            return aCall.uuid
        }
        return nil
    }
    
    func getCall(uuid: UUID) -> OpaquePointer? {
        for aCall in controllerCalls where aCall.uuid == uuid {
            return aCall.call
        }
        return nil
    }
    
    func getCallKitCall(uuid: UUID) -> CallKitCall? {
        for aCall in controllerCalls where aCall.uuid == uuid {
            return aCall
        }
        return nil
    }
    
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        os_log("CallKit : ========= Call changed UUID =========", log: log_app_debug, type: .debug)
        os_log("CallKit : Call UUID changed : %@", log: log_app_debug, type: .debug, call.uuid.uuidString)
        os_log("CallKit : Call is outgoing : %@", log: log_app_debug, type: .debug, call.isOutgoing ? "true" : "false")
        os_log("CallKit : Call is on hold : %@", log: log_app_debug, type: .debug, call.isOnHold ? "true" : "false")
        os_log("CallKit : Call has connected : %@", log: log_app_debug, type: .debug, call.hasConnected ? "true" : "false")
        os_log("CallKit : Call has ended : %@", log: log_app_debug, type: .debug, call.hasEnded ? "true" : "false")
        var isMatchCall: Bool = false
        for aCall in controllerCalls where aCall.uuid == call.uuid {
            os_log("CallKit : Match UUID in CallKitCall controller", log: log_app_debug, type: .debug)
            os_log("CallKit : Call name : %@", log: log_app_debug, type: .debug, getCallKitCall(uuid: call.uuid)!.callName)
            isMatchCall = true
            if call.hasEnded {
                os_log("CallKit : Call is ended, Remove call from controller", log: log_app_debug, type: .debug)
                Controller.removeControllerCall(call: aCall.call)
            }
            break
        }
        if !isMatchCall {
            os_log("CallKit : ========= Found GSM call =========", log: log_app_debug, type: .debug)
            os_log("CallKit : GSM call UUID : %@", log: log_app_debug, type: .debug, call.uuid.uuidString)
            if call.hasEnded {
                Controller.removeGSMCall(call: call)
                os_log("CallKit : GSM call is ended, Check conference room to resume all paused calls", log: log_app_debug, type: .debug, call.uuid.uuidString)
                if sipUAManager.isConferenceCreate() && sipUAManager.getConferenceSize() > 1 {
                    // Make local enter conference
                    sipUAManager.enterConference()
                    // Resume all paused calls that used to enter conference
                    for call in sipUAManager.getAllCalls() where sipUAManager.isCallInConference(call: call!) {
                        sipUAManager.resumeCall(call: call!)
                    }
//                    if let callingView = CallingView.viewControllerInstance() {
////                        // Update leave or enter conference view
////                        callingView.updatePauseConferenceStatus()
////                        // refresh call cell in table
////                        callingView.refreshPauseCallList()
////                        callingView.refreshConferenceCallList()
//                    }
                }
            } else {
                Controller.addGSMCall(call: call)
            }
        }
        os_log("CallKit : GSM calls : %@", log: log_app_debug, type: .debug, gsmCalls)
        os_log("CallKit : Controller calls : %@", log: log_app_debug, type: .debug, controllerCalls)
    }
    
}



