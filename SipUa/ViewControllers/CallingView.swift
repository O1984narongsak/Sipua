//
//  CallingView.swift
//  SipUa
//
//  Created by NLDeviOS on 20/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import SipUAFramwork
import LinphoneModule
import CallKit
import UserNotifications

/** Structure for pause/conference call */
public struct CallData {
    var call: OpaquePointer?
    var callID: String?
}



class CallingView: UIViewController {
    
    // Instance of this view controller
    private static var callingViewInstance: CallingView?
    
    // Linking container view
    @IBOutlet weak var contentView: UIView!
    
     // Linking select attended transfer call view
    @IBOutlet weak var selectPauseCV: UIView!
    @IBOutlet weak var selectPauseCtable: UITableView!
    @IBOutlet weak var selectPauseBtn: UIButton!
    @IBOutlet weak var selectCancelPBtn: UIButton!
    // View name to load to this view controller
    // The xib that's showing
    var xibName: String?
    // Class name to match with view that load
    // The class of xib that's linking
    var toClass: String?
    // A timer to update string calling time
    var callDurationTimer: Timer?
    // The property that contain a linphone call
    var mCall: OpaquePointer? = sipUAManager.getCurrentCall()
    // Class that's going to cast to
    var incomingSubView: IncomingCall!
    var outgoingSubView: OutgoingCall!
//    var audioCallSubView: AudioCall!
    var conferenceCallSubView: ConferenceCall!
    
    // Bluetooth status
    var bluetoothConnected: Bool = false
    var bluetoothEnabled: Bool = false
    // Headphones status
    var headphonesConnected: Bool = false
    var headphonesEnabled: Bool = false
    // Speaker status
    var speakerEnabled: Bool = false
    // Microphone status
    var microphoneMuted: Bool = false
    // To check call is paused or not
    var pauseCallStatus: Bool = false
    // An array to collect pause call data to set cell in pause call table
     var pauseCallArray: [CallData] = []
    
    // To temporary collect a pause call to attended transfer when there are multiple pause calls
    var tmpSelectPauseCall: CallData?
    
    // To keep speaker status before pause call, This happen when using CallKit
    var speakerBeforePause: Bool = false
    
    // To check is another call comming while app is making outgoing call/receiving incoming call
    var isAnotherCallComing: Bool = false
    
    // To check a local is a caller or callee for asking open video popup
    var isCaller: Bool = false
    
    // An array to collect call to set cell in conference call table
    var conferenceCallArray: [CallData] = []
    
    //recieved Call or not
    var isAccept = false
    
    // To check is select pause call table is show or not for reloading data in table in refreshPauseCallList()
    var isSelectPauseCallShow: Bool = false
    
    // MARK: - Instance
    /* Instance of this view controller */
    static func viewControllerInstance() -> CallingView? {
        if callingViewInstance == nil {
            // Add instance
            callingViewInstance = CallingView.instantiateFromAppStoryboard(appStoryboard: .Calling)
        }
        return callingViewInstance
    }
    
    /* Check instance of this view controller */
    static func isViewControllerInstanceCreated() -> Bool {
        if callingViewInstance != nil {
            return true
        }
        return false
    }
    
    // MARK: - Load view & class
    /* Load sepecific view and set sepecific class */
    func loadXibName(_ xibName: String,_ toClass: String) {
        
        // Load xib with name
        if let anyView = Bundle.main.loadNibNamed(xibName, owner: self, options: nil)?.first {
            
            // Cast to specification class by checking from "toClass" property
            // Cast to incoming call class
            if toClass == AppView.ClassName.IncomingCall {
                incomingSubView = (anyView as! IncomingCall)
                // Setup properties in view
                setupIncomingCallView()
                
                // Cast to ougoing call class
            } else if toClass == AppView.ClassName.OutgoingCall {
                outgoingSubView = (anyView as! OutgoingCall)
                // Setup properties in view
                setupOutgoingCallView()
                
                
                // Cast to audio call class
//            } else if toClass == AppView.ClassName.AudioCall {
//                audioCallSubView = (anyView as! AudioCall)
//                // Setup properties in view
//                setupAudioCallView()
        
                
                // Cast to video call class
            } else if toClass == AppView.ClassName.ConferenceCall {
                conferenceCallSubView = (anyView as! ConferenceCall)
                // Setup properties in view
                setupConferenceCallView()
            }
            
        }
    }
    
    /* Load a specific xib view and remove another */
    @discardableResult func refreshLoadContentView() -> LoadViewResult {
        os_log("CallingView : Count subview : %i", log: log_app_debug, type: .debug, contentView.subviews.count)
        // Get subview identifier for comparing with current showing view to prevent insert the same subview
        if contentView.subviews.count != 0 {
            os_log("CallingView : There are subviews in content view, Check subviews", log: log_app_debug, type: .debug)
            if let subviewIdentifier = contentView.subviews[0].accessibilityIdentifier {
                if xibName != subviewIdentifier {
                    os_log("CallingView : Subviews in content view is difference, Load subviews", log: log_app_debug, type: .debug)
                    loadXibName(xibName!, toClass!)
                } else {
                    os_log("CallingView : Don't load the same view!!", log: log_app_debug, type: .debug)
                    return LoadViewResult.NotLoadTheSameView
                }
            } else {
                os_log("CallingView : Subview [%@] is not set [accessibilityIdentifier] in .xib", log: log_app_error, type: .error, contentView.subviews[0])
                return LoadViewResult.AccessibilityIdentifierNotSet
            }
        } else {
            os_log("CallingView : No subviews in content view, Load subviews", log: log_app_debug, type: .debug)
            loadXibName(xibName!, toClass!)
        }
        
        // Check all subview and removing others subview except index 0
        checkAndRemoveOthersSubview()
        
        return LoadViewResult.LoadViewSuccess
    }
    
    /* Check all subview and removing subview from container view except subview[0] that's showing */
    func checkAndRemoveOthersSubview() {
        for view in contentView.subviews {
            if let identifier = view.accessibilityIdentifier {
                os_log("CallingView : Subview in container : %@", log: log_app_debug, type: .debug, identifier)
            } else {
                os_log("CallingView : Subview [%@] not set accessibilityIdentifier", log: log_app_debug, type: .debug, view)
            }
        }
        if contentView.subviews.count == 1 {
            os_log("CallingView : There is only 1 subview in container, No need to remove others", log: log_app_debug, type: .debug)
        }
        for (index,view) in contentView.subviews.enumerated() where index != 0 {
            os_log("CallingView : Remove view : %@", log: log_app_debug, type: .debug, view.accessibilityIdentifier ?? "nil")
            view.removeFromSuperview()
        }
    }
    
    func setupOutgoingCallView() {
        // Setup navigation bar image
        let iconFrame = CGRect(x: 0, y: 0, width: 130, height: 33)
    
        // Deregister device orientation notification when in other view
        os_log("CallingView : Remove observer for device rotation in outgoing call", log: log_app_debug, type: .debug)
        deregisterDeviceRotation()
        // Set outgoing text audio/video call

        // Set username text to callee username
        outgoingSubView.usernameTxt.text = sipUAManager.getRemoteDisplayName(call: nil) ?? sipUAManager.getRemoteUsername(call: nil)
        // Add target to speaker button
        outgoingSubView.muteSpeakerBtn.addTarget(self, action: #selector(enableSpeaker), for: .touchUpInside)
        // Update speaker button
        updateSpeakerStatus()
        // Add target to hangup button
        outgoingSubView.pauseBtn.addTarget(self, action: #selector(hangupCall), for: .touchUpInside)
        // Add subview with animation
        UIView.transition(with: contentView, duration: 0.2, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
            self.contentView.insertSubview(self.outgoingSubView, at: 0)
            
            // Adjust auto layout for bigger/smaller screen size
            self.fillSubViewToSuperView(subView: self.outgoingSubView, superView: self.contentView)
        }, completion: nil)
        os_log("CallingView : Finish load outgoing view", log: log_app_debug, type: .debug)
    }
    
    // MARK: - Setup view
    /* Setup all properties in AudioCallView */
    func setupAudioCallView() {
        if useCallKit {
            // Route audio to receiver
            sipUAManager.routeAudioToReceiver()
            // Set speaker before pause
            speakerBeforePause = false
        }
        // Setup navigation bar image
        let iconFrame = CGRect(x: 0, y: 0, width: 130, height: 33)
//        setupNavigationBarImageTitle(navigationBar: audioCallSubView.audioCallNavigationItem, frame: iconFrame, image: #imageLiteral(resourceName: "navigation_main_icon"))
        // Deregister device orientation notification when in other view
        os_log("CallingView : Remove observer for device rotation in audio call", log: log_app_debug, type: .debug)
        deregisterDeviceRotation()
        // Hide pause call table for first run
        preparePauseCallTable()
        // If there is some pause call
        if sipUAManager.countPausedCall() != 0 {
            showPauseCallTable()
        }

        // Set name text
        incomingSubView.usernameTxt.text = sipUAManager.getRemoteDisplayName(call: sipUAManager.getCurrentCall()) ?? sipUAManager.getRemoteUsername(call: sipUAManager.getCurrentCall())
        // Hide add new call popup background for first run
        prepareAddNewCallPopup()
        // Add target to new call button
        incomingSubView.keypadBtn.addTarget(self, action: #selector(showAddNewCallPopup), for: .touchUpInside)
        
        // Hide select pause call popup background for first run
        prepareSelectPauseCallPopup()
        // Add target to transfer call button
        incomingSubView.transferBtn.addTarget(self, action: #selector(attendedTransferCall), for: .touchUpInside)
        // Set attended transfer button for first run
        updateAttendedTransferButton()
        // Add target to conference call button
        incomingSubView.mergeBtn.addTarget(self, action: #selector(loadConferenceView), for: .touchUpInside)
        // Set conference button for first run
        updateConferenceButton()
        // Hide codec popup background for first run
//        prepareCodecDetailPopup()
        // Add target to codec details button
//        audioCallSubView.detailsBtn.addTarget(self, action: #selector(showCodecDetailPopup), for: .touchUpInside)
        // Add target to speaker button
        incomingSubView.muteSpeakerBtn.addTarget(self, action: #selector(enableSpeaker), for: .touchUpInside)
        // Update speaker button
        updateSpeakerStatus()
        
//        // Add target to bluetooth button
//        audioCallSubView.bluetoothBtn.addTarget(self, action: #selector(enableBluetooth), for: .touchUpInside)
        
        // Update bluetooth button
//        updateBluetoothStatus()
        
        // Add target to microphone button
        incomingSubView.muteBtn.addTarget(self, action: #selector(enableMicrophone), for: .touchUpInside)
        // Set microphone unmute
        sipUAManager.muteMic(status: microphoneMuted)
        // Update microphone button
        updateMicrophoneStatus()
        // Add target to pause button
        incomingSubView.pauseBtn.addTarget(self, action: #selector(pauseCall), for: .touchUpInside)
        // Update pause button image
        updatePauseCallStatus()
        // Switch calling to video
//        incomingSubView.videoCallBtn.addTarget(self, action: #selector(switchToVideo), for: .touchUpInside)
        
        // Add target to hangup button
        incomingSubView.phoneBtn.addTarget(self, action: #selector(hangupCall), for: .touchUpInside)
        // Hide a pause view for first run
        if sipUAManager.getStateOfCall(call: mCall) == LinphoneCallStatePausedByRemote ||
            sipUAManager.getStateOfCall(call: mCall) == LinphoneCallStatePaused {
//            incomingSubView.pauseView.alpha = 1
        } else {
//            incomingSubView.pauseView.alpha = 0
        }
        // CallKit
        if useCallKit {
            // Add subview with animation
            UIView.transition(with: contentView, duration: 0.2, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
//                self.contentView.insertSubview(self.audioCallSubView, at: 0)
                // Adjust auto layout for bigger/smaller screen size
//                self.fillSubViewToSuperView(subView: self.audioCallSubView, superView: self.contentView)
            }, completion: {(success: Bool) in
                if self.view.isHidden {
//                    UIView.animate(withDuration: 0.2, animations: {
//                        // Show calling view storyboard if hidden
//                        self.view.isHidden = false
//                    })
                }
            })
        } else {
            // Add subview with animation
            UIView.transition(with: contentView, duration: 0.2, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
//                self.contentView.insertSubview(self.audioCallSubView, at: 0)
                // Adjust auto layout for bigger/smaller screen size
//                self.fillSubViewToSuperView(subView: self.audioCallSubView, superView: self.contentView)
            }, completion: nil)
        }
        os_log("CallingView : Finish load audio view", log: log_app_debug, type: .debug)
    }
    
    /* Setup all properties in IncomingCallView */
    func setupIncomingCallView() {
        // Setup navigation bar image
//        let iconFrame = CGRect(x: 0, y: 0, width: 130, height: 33)
        
//        setupNavigationBarImageTitle(navigationBar: CallingView., frame: iconFrame, image: #imageLiteral(resourceName: "incoming"))
        
        // Deregister device orientation notification when in other view
        os_log("CallingView : Remove observer for device rotation in incoming call", log: log_app_debug, type: .debug)
        deregisterDeviceRotation()
        // Set incoming text audio/video call
        // Set visible/invisible to accept video button if incoming is audio/video call
   
            incomingSubView.incomingHeadTxt.text = "Incoming Audio Call"
   
   
        // Add target to accept or decline audio call
        isAccept = !isAccept
        if isAccept{
            incomingSubView.phoneBtn.addTarget(self, action: #selector(acceptAudioCall), for: .touchUpInside)
        }else{
            incomingSubView.phoneBtn.addTarget(self, action: #selector(declineCall), for: .touchUpInside)
        }
        

        // Set username text to caller username
        if isAnotherCallComing {
            os_log("CallingView : Overlap incoming call", log: log_app_debug, type: .debug)
            for call in sipUAManager.getAllCalls() where sipUAManager.getStateOfCall(call: call) == LinphoneCallStateIncomingReceived {
                incomingSubView.usernameTxt.text = sipUAManager.getRemoteDisplayName(call: call) ?? sipUAManager.getRemoteUsername(call: call)
                break
            }
        } else {
            incomingSubView.usernameTxt.text = sipUAManager.getRemoteDisplayName(call: nil) ?? sipUAManager.getRemoteUsername(call: nil)
        }
        // Add target to decline button
        
        // CallKit
        // Because we use CallKit to show native incoming call UI for first incoming call, We don't want to see app incoming call view
        // Case normal
        //  - There is one running call, Incoming call received
        // Case overlap incoming call
        //  - User make outgoing call, there is incoming call, hangup outgoing call
        if useCallKit && !Provider.shouldShowIncomingCallView() && !isAnotherCallComing {
            
            os_log("CallingView : Load incoming view but hide it", log: log_app_debug, type: .debug)
            
            // Hide view and insert subview
            UIView.transition(with: contentView, duration: 0.05, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
                // Hide calling view storyboard
                self.view.isHidden = true
            }) { (success: Bool) in
                self.contentView.insertSubview(self.incomingSubView, at: 0)
                // Adjust auto layout for bigger/smaller screen size
                self.fillSubViewToSuperView(subView: self.incomingSubView, superView: self.contentView)
            }
        } else {
            os_log("CallingView : Load incoming view normally", log: log_app_debug, type: .debug)
            // Add subview with animation
            UIView.transition(with: contentView, duration: 0.2, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
                self.contentView.insertSubview(self.incomingSubView, at: 0)
                // Adjust auto layout for bigger/smaller screen size
                self.fillSubViewToSuperView(subView: self.incomingSubView, superView: self.contentView)
            }, completion: nil)
        }
        os_log("CallingView : Finish load incoming view", log: log_app_debug, type: .debug)
        setupAudioCallView()
    }
    
    /* Setup all properties in ConferenceCallView */
    func setupConferenceCallView() {
        
        // Setup navigation bar image
        let iconFrame = CGRect(x: 0, y: 0, width: 130, height: 33)
        
//        setupNavigationBarImageTitle(navigationBar: conferenceCallSubView.conferenceCallNavigationItem, frame: iconFrame, image: #imageLiteral(resourceName: "navigation_main_icon"))
        // Deregister device orientation notification when in other view
        os_log("CallingView : Remove observer for device rotation in conference call", log: log_app_debug, type: .debug)
        
        deregisterDeviceRotation()
        // Prepare conference pause call table for first run
        
        preparePauseCallTable()
        // Prepare pause call table for first run
        
        prepareConferenceTable()
        // Set call status for first run
        
//        conferenceCallSubView.status.text = SipUtils.callStateToString(callState: sipUAManager.getStateOfCall(call: mCall))
        // Add target to speaker button
        
        conferenceCallSubView.speakerBtn.addTarget(self, action: #selector(enableSpeaker), for: .touchUpInside)
        
        // Update speaker button
        updateSpeakerStatus()
        
        // Add target to microphone button
        conferenceCallSubView.microphonBtn.addTarget(self, action: #selector(enableMicrophone), for: .touchUpInside)
        // Set microphone unmute
        sipUAManager.muteMic(status: microphoneMuted)
        
        // Update microphone button
        updateMicrophoneStatus()
        
        // Add target to new call button
        conferenceCallSubView.newCallBtn.addTarget(self, action: #selector(showAddNewCallPopup), for: .touchUpInside)
        
        // Hide add new call popup background for first run
        prepareAddNewCallPopup()
        
        // Hide a pause view for first run
        if sipUAManager.isInConference() {
            conferenceCallSubView.pauseCallBtn.alpha = 0
        } else {
            conferenceCallSubView.pauseCallBtn.alpha = 1
        }
        
        // Add target to pause conference button
//        conferenceCallSubView.pauseCallBtn.addTarget(self, action: #selector(addOrRemoveLocalFromConference), for: .touchUpInside)
        
        // Update pause conference button and pause view
//        updatePauseConferenceStatus()
        
        // Add target to hangup button
//        conferenceCallSubView.hangupBtn.addTarget(self, action: #selector(terminateConference), for: .touchUpInside)
        
        // Add subview with animation
//        UIView.transition(with: contentView, duration: 0.2, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
//            self.contentView.insertSubview(self.conferenceCallSubView, at: 0)
//            // Adjust auto layout for bigger/smaller screen size
//            self.fillSubViewToSuperView(subView: self.conferenceCallSubView, superView: self.contentView)
//        }, completion: nil)
        os_log("CallingView : Finish load conference view", log: log_app_debug, type: .debug)
    }
    
    /* Attended transfer call */
    @objc func attendedTransferCall() {
        // In case attended transfer call, Must be 1 running call and 1 pause call at least
        if sipUAManager.countRunningCall() != 0 && sipUAManager.countPausedCall() != 0 {
            // If there is only 1, Get that pause call from all call
            if sipUAManager.countPausedCall() == 1 {
                for pauseCall in sipUAManager.getAllCalls() where sipUAManager.getStateOfCall(call: pauseCall) == LinphoneCallStatePaused {
                    sipUAManager.transferToAnother(callToTransfer: pauseCall!, destination: sipUAManager.getCurrentCall()!)
                }
                // If there are multiple pause calls, Show view to select to attended transfer call
            } else {
                showSelectPauseCallPopup()
            }
        } else {
            os_log("CallingView : No running call or no pause call : Can't attended transfer call", log: log_app_error, type: .error)
            return
        }
    }
    
    /* Confirm attended transfer call on popup */
    @objc func confirmAttendedTransferCall() {
        if tmpSelectPauseCall != nil && sipUAManager.getCurrentCall() != nil {
            hideSelectPauseCallPopup()
            sipUAManager.transferToAnother(callToTransfer: tmpSelectPauseCall!.call!, destination: sipUAManager.getCurrentCall()!)
        } else {
            os_log("CallingView : No select pause call to attended tranfer : Can't attended transfer call", log: log_app_error, type: .error)
            return
        }
    }
    
    /* Show a popup view to select a pause call */
    @objc func showSelectPauseCallPopup() {
        os_log("CallingView : Show select pause call", log: log_app_debug, type: .debug)
        // Add subview
        contentView.addSubview(selectPauseCV)
        // Set start properties
        selectPauseCV.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        // Animate
        UIView.animate(withDuration: 0.2, animations: {
            self.selectPauseCV.transform = CGAffineTransform.identity
            self.selectPauseCV.alpha = 1
            if self.toClass == AppView.ClassName.IncomingCall {
//                self.audioCallSubView.popupBackground.alpha = 1
            } else if self.toClass == AppView.ClassName.OutgoingCall {
//                self.videoCallSubView.popupBackground.alpha = 1
            }
        }, completion: { (success: Bool) in
            // Set showing status
            self.isSelectPauseCallShow = true
            // Add gasture to hide codec details view
            let tapToClosePopupGasture = UITapGestureRecognizer(target: self, action: #selector(self.hideSelectPauseCallPopup))
            if self.toClass == AppView.ClassName.IncomingCall {
//                self.audioCallSubView.popupBackground.addGestureRecognizer(tapToClosePopupGasture)
            } else if self.toClass == AppView.ClassName.OutgoingCall {
//                self.videoCallSubView.popupBackground.addGestureRecognizer(tapToClosePopupGasture)
            }
            // Add button action
            self.selectPauseBtn.addTarget(self, action: #selector(self.confirmAttendedTransferCall), for: .touchUpInside)
            self.selectCancelPBtn.addTarget(self, action: #selector(self.hideSelectPauseCallPopup), for: .touchUpInside)
        })
    }
    
    /* Hide a popup view to select a pause call */
    @objc func hideSelectPauseCallPopup() {
        os_log("CallingView : Hide select pause call", log: log_app_debug, type: .debug)
        // Animate
        UIView.animate(withDuration: 0.2, animations: {
            self.selectPauseCV.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            self.selectPauseCV.alpha = 0
            if self.toClass == AppView.ClassName.IncomingCall {
//                self.audioCallSubView.popupBackground.alpha = 0
            } else if self.toClass == AppView.ClassName.OutgoingCall {
//                self.videoCallSubView.popupBackground.alpha = 0
            }
        }, completion: { (success: Bool) in
            // Set showing status
            self.isSelectPauseCallShow = false
            // Clear temporary select pause call
            self.tmpSelectPauseCall = nil
            // Remove subview
            self.selectPauseCV.removeFromSuperview()
            // Remove button action
            self.selectPauseBtn.removeTarget(self, action: #selector(self.confirmAttendedTransferCall), for: .touchUpInside)
            self.selectCancelPBtn.removeTarget(self, action: #selector(self.hideSelectPauseCallPopup), for: .touchUpInside)
        })
    }
    
  
    
    /* Remove device rotation */
    func deregisterDeviceRotation() {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    /* Set background picture of microphone button */
    func updateMicrophoneStatus() {
        if microphoneMuted {
            // If current view is audiocall/videocall/conference
            if toClass == AppView.ClassName.IncomingCall {
//                IncomingCall.muteBtn.setImage(UIImage(named: "Sp_Mute"), for: UIControl.State.normal)
            }  else if toClass == AppView.ClassName.ConferenceCall {
                conferenceCallSubView.microphonBtn.setImage(UIImage(named: "Sp_Mute"), for: UIControl.State.normal)
            }
        } else {
            if toClass == AppView.ClassName.IncomingCall {
//                audioCallSubView.microphoneBtn.setImage(UIImage(named: "Sp_unMute"), for: UIControl.State.normal)
            }  else if toClass == AppView.ClassName.ConferenceCall {
                conferenceCallSubView.microphonBtn.setImage(UIImage(named: "Sp_unMute"), for: UIControl.State.normal)
            }
        }
    }
    
    // MARK: - Speaker notification
    /* Update a speaker state enabled from library */
    @objc func speakerStateUpdate(notification: Notification) {
        speakerEnabled = notification.userInfo!["enabled"] as! Bool
        updateSpeakerStatus()
    }
    
    /* Set background picture of speaker button */
    func updateSpeakerStatus() {
        os_log("CallingView : Speaker status : Enabled [%@]", log: log_app_debug, type: .debug, speakerEnabled ? "true" : "false")
        if speakerEnabled {
            // If current view is outgoing/audiocall/videocall
            if toClass == AppView.ClassName.OutgoingCall {
                outgoingSubView.muteSpeakerBtn.setImage(#imageLiteral(resourceName: "Mic_unMute"), for: UIControl.State.normal)
            } else if toClass == AppView.ClassName.IncomingCall {
//                audioCallSubView.speakerBtn.setImage(#imageLiteral(resourceName: "speaker_enable"), for: UIControl.State.normal)
                
            }  else if toClass == AppView.ClassName.ConferenceCall {
                conferenceCallSubView.speakerBtn.setImage(#imageLiteral(resourceName: "Mic_unMute"), for: UIControl.State.normal)
            }
        } else {
            if toClass == AppView.ClassName.OutgoingCall {
                outgoingSubView.muteSpeakerBtn.setImage(#imageLiteral(resourceName: "Mic_Mute"), for: UIControl.State.normal)
            } else if toClass == AppView.ClassName.IncomingCall {
//                audioCallSubView.speakerBtn.setImage(#imageLiteral(resourceName: "speaker_disable"), for: UIControl.State.normal)
            }  else if toClass == AppView.ClassName.ConferenceCall {
                conferenceCallSubView.speakerBtn.setImage(#imageLiteral(resourceName: "Mic_Mute"), for: UIControl.State.normal)
            }
        }
    }
    
    /* Enable/disable speaker */
    @objc func enableSpeaker() {
        if sipUAManager.isSpeakerEnabled() {
            // Auto route audio to enable device
            if sipUAManager.isBluetoothConnected() {
                sipUAManager.routeAudioToBluetooth()
            } else if sipUAManager.isHeadphonesConnected() {
                sipUAManager.routeAudioToHeadphones()
            } else {
                sipUAManager.routeAudioToReceiver()
                // Set speaker before pause
                speakerBeforePause = false
            }
        } else {
            // Route audio to speaker
            sipUAManager.routeAudioToSpeaker()
            // Set speaker before pause
            speakerBeforePause = true
        }
        // Update speaker button
        updateSpeakerStatus()
    }
    
    /* Enable/disable microphone */
    @objc func enableMicrophone() {
        if sipUAManager.isMicMute() {
            if useCallKit {
                // CallKit
                if let uuid = Controller.getUUID(call: mCall!) {
                    os_log("CallingView : Request to unmute microphone", log: log_app_debug, type: .debug)
                    Controller.muteCall(uuid: uuid, onMute: false)
                } else {
                    os_log("CallingView : Can't get uuid from call to mute microphone", log: log_app_error, type: .error)
                }
            } else {
                // If microphone off, Turn on
                sipUAManager.muteMic(status: false)
            }
            
        } else {
            if useCallKit {
                // CallKit
                if let uuid = Controller.getUUID(call: mCall!) {
                    os_log("CallingView : Request to mute microphone", log: log_app_debug, type: .debug)
                    Controller.muteCall(uuid: uuid, onMute: true)
                } else {
                    os_log("CallingView : Can't get uuid from call to mute microphone", log: log_app_error, type: .error)
                }
            } else {
                // If microphone on, Turn off
                sipUAManager.muteMic(status: true)
            }
            
        }
        // Update microphone button
        updateMicrophoneStatus()
    }
    
    /* Hangup for outgoing call */
    @objc func hangupCall() {
        os_log("CallingView : Press hangup call", log: log_app_debug, type: .debug)
        // In case overlap incoming call, show incoming call view, accept call
        if isAnotherCallComing {
            os_log("CallingView : There is another call received", log: log_app_debug, type: .debug)
            var countCall = 0
            for call in sipUAManager.getAllCalls() {
                let state = sipUAManager.getStateOfCall(call: call)
                if state == LinphoneCallStateOutgoingInit || state == LinphoneCallStateOutgoingProgress || state == LinphoneCallStateOutgoingRinging {
                    os_log("CallingView : Hangup call username : %@", log: log_app_debug, type: .debug, sipUAManager.getRemoteUsername(call: call)!)
                    countCall += 1
                    sipUAManager.hangUp(call: call)
                    break
                }
            }
            // To check in case press hangup but no outgoing call
            if countCall == 0 {
                os_log("CallingView : Not found outgoing call, Hangup call normally", log: log_app_debug, type: .debug)
                sipUAManager.hangUp(call: nil)
            }
        } else {
            os_log("CallingView : Hangup call normally", log: log_app_debug, type: .debug)
            sipUAManager.hangUp(call: nil)
        }
        // Stop timer to get call duration
        stopCallDurationTimer()
    }
    
    /* Pause/resume for call */
    @objc func pauseCall() {
        os_log("CallingView : Press pause call", log: log_app_debug, type: .debug)
        // Check pause call status
        if !pauseCallStatus {
            // Get current call to pause
            if let currentCall = sipUAManager.getCurrentCall() {
                os_log("CallingView : Pause running call id : %@", log: log_app_debug, type: .debug, sipUAManager.getCallCallID(call: currentCall))
                // Pause call
                sipUAManager.pauseCall(call: currentCall)
            } else {
                os_log("CallingView : Cen't pause call because no running call", log: log_app_debug, type: .debug)
                return
            }
        }
    }
    
    // MARK: - Call duration timer
    /* Start timer to update call duration */
    func startCallDurationTimer() {
        // Don't start timer if in conference view
        if callDurationTimer == nil && toClass != AppView.ClassName.ConferenceCall {
            os_log("CallingView : Start call duration timer", log: log_app_debug, type: .debug)
            updateCallingTime()
            callDurationTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateCallingTime), userInfo: nil, repeats: true)
        }
        // Show call duration text if timer start
        if toClass == AppView.ClassName.IncomingCall {
            UIView.animate(withDuration: 0.2, animations: {
//                self.audioCallSubView.durationtxt.alpha = 1
            })
        }
    }
    
    /* Function for timer to get call duration string */
    @objc func updateCallingTime() {
        if toClass == AppView.ClassName.IncomingCall {
//            audioCallSubView.durationtxt.text = sipUAManager.getCallDurationUpdate(call: nil)
        }
    }
    
    /* Stop timer for update call duration */
    func stopCallDurationTimer() {
        os_log("CallingView : Stop call duration timer", log: log_app_debug, type: .debug)
        if callDurationTimer != nil {
            callDurationTimer?.invalidate()
            callDurationTimer = nil
            
        }
        // Hide call duration text if timer stop
        if toClass == AppView.ClassName.IncomingCall {
            UIView.animate(withDuration: 0.2, animations: {
//                self.audioCallSubView.durationtxt.alpha = 0
            })
        } else if toClass == AppView.ClassName.OutgoingCall {
            UIView.animate(withDuration: 0.2, animations: {
//                self.videoCallSubView.durationtxt.alpha = 0
            })
        }
    }
    
    /* Accept for incoming audio call */
    @objc func acceptAudioCall() {
        os_log("CallingView : Press accept audio call", log: log_app_debug, type: .debug)
        // In case overlap incoming call, show incoming call view, accept call
        if isAnotherCallComing && useCallKit {
            os_log("CallingView : There is another call received", log: log_app_debug, type: .debug)
            for call in sipUAManager.getAllCalls() where sipUAManager.getStateOfCall(call: call) == LinphoneCallStateIncomingReceived {
                os_log("CallingView : Accept audio call username : %@", log: log_app_debug, type: .debug, sipUAManager.getRemoteUsername(call: call)!)
                // In case overlap incoming call, end incoming call native UI, app will enter foreground, show another incoming call view, answer a call
                // Will cause no CallKit to active call for running in background
                if Controller.getControllerCalls().count == 0 {
                    os_log("CallingView : No active CallKit, Active it", log: log_app_debug, type: .debug)
                    // Start call
                    let uuid = UUID()
                    let callName = (sipUAManager.getRemoteDisplayName(call: call) ?? sipUAManager.getRemoteUsername(call: call)) ?? "Unknown"
                    os_log("CallingView : Start CallKit call name : %@", log: log_app_debug, type: .debug, callName)
                    // Set isOutgoing input to true for being called in call state change streams running
                    Controller.startCall(uuid: uuid, handle: callName, call: call!, isVideo: false, isOutgoing: true)
                    // In case make outgoing call, there is incoming call, accept incoming call
                } else {
                    os_log("CallingView : Found active CallKit, Continue check outgoing call", log: log_app_debug, type: .debug)
                    if sipUAManager.countOutgoingCall() != 0 {
                        os_log("CallingView : Found outgoing call", log: log_app_debug, type: .debug)
                        os_log("CallingView : All call in controller : %i", log: log_app_debug, type: .debug, Controller.getControllerCalls().count)
                        // Temporary keep outgoing CallKit uuid
                        let callKitUUID = Controller.getControllerCalls().last?.uuid
                        // Start call
                        let uuid = UUID()
                        let callName = (sipUAManager.getRemoteDisplayName(call: call!) ?? sipUAManager.getRemoteUsername(call: call)) ?? "Unknown"
                        os_log("CallingView : Start CallKit call name : %@", log: log_app_debug, type: .debug, callName)
                        // Set isOutgoing input to true for being called in call state change streams running
                        Controller.startCall(uuid: uuid, handle: callName, call: call!, isVideo: false, isOutgoing: true)
                        // Calling end CallKit later because provider callback function [Activate audio session and Deacivate audio session]
                        // are not called as sequence, Then we have to make sure that activate audio session called first
                        os_log("CallingView : End the previous CallKit and hangup a call", log: log_app_debug, type: .debug)
                        Controller.endCall(uuid: callKitUUID!)
                    } else {
                        os_log("CallingView : Not found outgoing call, Use answer function", log: log_app_debug, type: .debug)
                        sipUAManager.answer(call: call, withVideo: false)
                    }
                }
                break
            }
        } else {
            os_log("CallingView : Accept audio call normally", log: log_app_debug, type: .debug)
            sipUAManager.answer(call: nil, withVideo: false)
        }
    }
    
    /* Decline for incoming call */
    @objc func declineCall() {
        os_log("CallingView : Press decline call", log: log_app_debug, type: .debug)
        // In case overlap incoming call, show incoming call view, accept call
        if isAnotherCallComing {
            os_log("CallingView : There is another call received", log: log_app_debug, type: .debug)
            for call in sipUAManager.getAllCalls() where sipUAManager.getStateOfCall(call: call) == LinphoneCallStateIncomingReceived {
                os_log("CallingView : Decline call username : %@", log: log_app_debug, type: .debug, sipUAManager.getRemoteUsername(call: call)!)
                sipUAManager.decline(call: call)
                break
            }
        } else {
            os_log("CallingView : Decline call normally", log: log_app_debug, type: .debug)
            sipUAManager.decline(call: nil)
        }
    }
    
    /* Show pause call table */
    func showPauseCallTable() {
        os_log("CallingView : Show pause call table", log: log_app_debug, type: .debug)
        if toClass == AppView.ClassName.IncomingCall {
            // Start animation
            UIView.animate(withDuration: 0.2, animations: {
                self.incomingSubView.pauseBtn.alpha = 1
            })
        }
    }
    
    // MARK: - Select pause call popup
    /* Prepare select pause call popup */
    func prepareSelectPauseCallPopup() {
        // Set cornor and center to select pause call popup view
        selectPauseCV.layer.cornerRadius = 10
        selectPauseCV.center = self.view.center
        selectPauseCV.alpha = 0
        selectPauseCV.layer.cornerRadius = 10
        // Set data source to show data in table
        selectPauseCtable.dataSource = self
        selectPauseCtable.delegate = self
        // If showing view is audio
        if toClass == AppView.ClassName.IncomingCall {
            // Set background for select pause call popup
//            audioCallSubView.popupBackground.alpha = 0
            // If showing view is video
        } else if toClass == AppView.ClassName.OutgoingCall {
            // Set background for select pause call popup
//            videoCallSubView.popupBackground.alpha = 0
        }
    }
    
    // MARK: - New call popup
    /* Prepare add new call popup */
    func prepareAddNewCallPopup() {
        // Set cornor and center to add new call popup view
//        self.addNewCallView.layer.cornerRadius = 10
//        self.addNewCallView.center = self.view.center
//        self.addNewCallView.alpha = 0
        
        // If showing view is audio
        if self.toClass == AppView.ClassName.OutgoingCall {
            // Set background for add new call popup
//            self.audioCallSubView.popupBackground.alpha = 0

            // If showing view is conference
        } else if self.toClass == AppView.ClassName.ConferenceCall {
//            // Set background for add new call popup
//            self.conferenceCallSubView.popupBackground.alpha = 0
        }
    }
    
    // MARK: - Conference call table
    /* Prepare a conference call table */
    func prepareConferenceTable() {
        conferenceCallSubView.conferenceCallTable.layer.cornerRadius = 10
        // Set data source to show data in table
        conferenceCallSubView.conferenceCallTable.dataSource = self
        conferenceCallSubView.conferenceCallTable.delegate = self
    }
    
    /* Load a conference view */
    @objc func loadConferenceView() {
        // Add all to conference
        sipUAManager.addAllToConference()
        // If a local participant is not in conference then add it
        if !sipUAManager.isInConference() {
            sipUAManager.enterConference()
        }
        // Set conference property
        isConference = true
        // Load conference view
        toClass = AppView.ClassName.ConferenceCall
        xibName = AppView.XibName.ConferenceCall
        refreshLoadContentView()
    }
    
    // MARK: - Pause call Table
    /* Prepare a pause call table */
    func preparePauseCallTable() {
        if toClass == AppView.ClassName.ConferenceCall {
            conferenceCallSubView.pauseCallTable.layer.cornerRadius = 10
            // Set data source to show data in table
            conferenceCallSubView.pauseCallTable.dataSource = self
            conferenceCallSubView.pauseCallTable.delegate = self
        } else if toClass == AppView.ClassName.IncomingCall {
            
//            audioCallSubView.pauseCallTable.layer.cornerRadius = 10
//            // Set data source to show data in table
//            audioCallSubView.pauseCallTable.dataSource = self
//            audioCallSubView.pauseCallTable.delegate = self
//            audioCallSubView.pauseCallTable.alpha = 0
        }
        
    }
    
    /* Show a popup view to make a new call */
    @objc func showAddNewCallPopup() {
        os_log("CallingView : Show add new call", log: log_app_debug, type: .debug)
        // Add subview
        
//        self.contentView.addSubview(self.addNewCallView)
        // Set start properties
        
//        self.addNewCallView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        // Animate
        
        UIView.animate(withDuration: 0.2, animations: {
//            self.addNewCallView.transform = CGAffineTransform.identity
//            self.addNewCallView.alpha = 1
//            if self.toClass == AppView.ClassName.AudioCall {
//                self.audioCallSubView.popupBackground.alpha = 1
//            }  else if self.toClass == AppView.ClassName.ConferenceCall {
//                self.conferenceCallSubView.popupBackground.alpha = 1
//            }
        }, completion: { (success: Bool) in
            
            // Add gasture to hide codec details view
            
//            let tapToClosePopupGasture = UITapGestureRecognizer(target: self, action: #selector(self.hideAddNewCallPopup))
            if self.toClass == AppView.ClassName.OutgoingCall {
//                self.audioCallSubView.popupBackground.addGestureRecognizer(tapToClosePopupGasture)
            } else if self.toClass == AppView.ClassName.IncomingCall {
//                self.videoCallSubView.popupBackground.addGestureRecognizer(tapToClosePopupGasture)
            } else if self.toClass == AppView.ClassName.ConferenceCall {
//                self.conferenceCallSubView.popupBackground.addGestureRecognizer(tapToClosePopupGasture)
            }
            
            // Add button action
            
//            self.addNewCallAudioBtn.addTarget(self, action: #selector(self.makeNewAudioCall), for: .touchUpInside)
//            self.addNewCallTransferBtn.addTarget(self, action: #selector(self.normalTransferCall), for: .touchUpInside)
            
            // Set transfer button to enable/disable and set disable for conference view
            
            if sipUAManager.countRunningCall() == 0 || self.toClass == AppView.ClassName.ConferenceCall {
//                self.addNewCallTransferBtn.isEnabled = false
//            } else {
//                self.addNewCallTransferBtn.isEnabled = true
            }
        })
        
    }
    
    // MARK: - Update buttons
    /* Set background picture of pause call button */
    func updatePauseCallStatus() {
        if pauseCallStatus {
            if toClass == AppView.ClassName.IncomingCall {
                incomingSubView.pauseBtn.setImage(#imageLiteral(resourceName: "pause_call_enable"), for: UIControl.State.normal)
            } else if toClass == AppView.ClassName.OutgoingCall {
                outgoingSubView.pauseBtn.setImage(#imageLiteral(resourceName: "pause_call_enable"), for: UIControl.State.normal)
            }
        } else {
            if toClass == AppView.ClassName.IncomingCall {
                incomingSubView.pauseBtn.setImage(#imageLiteral(resourceName: "pause_call_disable"), for: UIControl.State.normal)
            } else if toClass == AppView.ClassName.OutgoingCall {
                outgoingSubView.pauseBtn.setImage(#imageLiteral(resourceName: "pause_call_disable"), for: UIControl.State.normal)
            }
        }
    }
    
    /* Update attended transfer button that can transfer/can not transfer */
    func updateAttendedTransferButton() {
        // Set transfer button to enable
        if sipUAManager.getCallsNumber() > 1 && sipUAManager.countRunningCall() == 1 && sipUAManager.countPausedCall() != 0 {
            if toClass == AppView.ClassName.IncomingCall {
                incomingSubView.transferBtn.isEnabled = true
            } else if toClass == AppView.ClassName.OutgoingCall {
                outgoingSubView.transferBtn.isEnabled = true
            }
            // Set transfer button to disable
        } else {
            if toClass == AppView.ClassName.IncomingCall {
                incomingSubView.transferBtn.isEnabled = false
            } else if toClass == AppView.ClassName.OutgoingCall {
                outgoingSubView.transferBtn.isEnabled = false
            }
        }
    }
    
    /* Update conference button that can enter conference/can not enter conference/there is conference number that paused */
    func updateConferenceButton() {
        // Set conference button to enable
        if sipUAManager.getCallsNumber() > 1 {
            if toClass == AppView.ClassName.IncomingCall {
                incomingSubView.mergeBtn.isEnabled = true
                // Check conference size, In case local is in conference and make a new call
                if sipUAManager.getConferenceSize() != 0 {
//                    audioCallSubView.conferenceRedDot.alpha = 1
//                    audioCallSubView.conferenceRedDot.setTitle(String(sipUAManager.getConferenceSize()), for: UIControl.State.normal)
                } else {
//                    audioCallSubView.conferenceRedDot.alpha = 0
                }
            } else if toClass == AppView.ClassName.OutgoingCall {
                outgoingSubView.mergeBtn.isEnabled = true
                if sipUAManager.getConferenceSize() != 0 {
//                    outgoingSubView.conferenceRedDot.alpha = 1
//                    videoCallSubView.conferenceRedDot.setTitle(String(sipUAManager.getConferenceSize()), for: UIControl.State.normal)
                } else {
//                    videoCallSubView.conferenceRedDot.alpha = 0
                }
            }
            // Set conference button to disable
        } else {
            if toClass == AppView.ClassName.IncomingCall {
            incomingSubView.mergeBtn.isEnabled = false
//            IncomingCall.conferenceRedDot.alpha = 0
            } else if toClass == AppView.ClassName.OutgoingCall {
                incomingSubView.mergeBtn.isEnabled = false
//                videoCallSubView.conferenceRedDot.alpha = 0
            }
        }
    }
    
    
    
}

// MARK: - Extension for pause call table view cell delegate
extension CallingView: PauseCallCellDelegate {
    // The reason that we use delegate of cell is we want to update main pause call button
    func tapResumeCall(call: OpaquePointer) {
        os_log("CallingView : Press resume call username : %@", log: log_app_debug, type: .debug, sipUAManager.getRemoteUsername(call: call) ?? "nil")
        if (isAnotherCallComing || !autoResumeCall) && useCallKit {
            // In case overlap incoming call and normal incoming call
            //  - Accept incoming call with native UI, accept another incoming call, hangup call active with CallKit, resume a remain pause call(CallKit is gone)
            if Controller.getControllerCalls().count == 0 {
                os_log("CallingView : No active CallKit, Active it", log: log_app_debug, type: .debug)
                // Start call
                let uuid = UUID()
                let isVideoCall = sipUAManager.isRemoteVideoEnabled(call: call)
                let callName = (sipUAManager.getRemoteDisplayName(call: call) ?? sipUAManager.getRemoteUsername(call: call)) ?? "Unknown"
                os_log("CallingView : Start CallKit call name : %@", log: log_app_debug, type: .debug, callName)
                // Set isOutgoing input to false for not being called in call state change streams running
                Controller.startCall(uuid: uuid, handle: callName, call: call, isVideo: isVideoCall, isOutgoing: false)
                // Have to force set connected call manually (Don't have to wait call state change)
                let callDuration = 0 - sipUAManager.getCallDuration(call: call)
                let timeinterval = TimeInterval(callDuration)
                let startTime = Date(timeIntervalSinceNow: timeinterval)
                Provider.callProvider.reportOutgoingCall(with: uuid, startedConnectingAt: startTime)
                Provider.callProvider.reportOutgoingCall(with: uuid, connectedAt: startTime)
                Controller.getCallKitCall(uuid: uuid)?.isConnected = true
            } else {
                os_log("CallingView : Found active CallKit, Use resume function", log: log_app_debug, type: .debug)
                // Resume a call from pause call cell
                sipUAManager.resumeCall(call: call)
            }
        } else {
            os_log("CallingView : Resume call normally", log: log_app_debug, type: .debug)
            // Resume a call from pause call cell
            sipUAManager.resumeCall(call: call)
        }
    }
}

// MARK: - Extension for conference call table view cell delegate
extension CallingView: ConferenceCallCellDelegate {
    // The reason that we use delegate of cell is we want to update conference call list and show audio/video view if no conference call
    func tapLeaveConferenceCall(call: OpaquePointer) {
        os_log("CallingView : Press leave conference", log: log_app_debug, type: .debug)
        // Remove a call from conference using conference call cell
        sipUAManager.removeCallFromConference(call: call)
        // If there is no conference call in array then show audio/video view
        // Check conference size
        if sipUAManager.getConferenceSize() < 2 {
            os_log("CallingView : Conference size is less than 2, Load audio/video view", log: log_app_debug, type: .debug)
            // Clear conference if there are only 2 calls
            sipUAManager.clearConference()
            
            // Load audio/video view
//            showViewForCall()
        }
        // Update conference status again to show/hide red dot conference number
//        updateConferenceButton()
    }
}

// MARK: - Extension for conference pause call table view cell delegate
extension CallingView: ConferencePauseCallCellDelegate {
    // The reason that we use delegate of cell is we want to update conference call list and show audio/video view if no conference call
    func tapEnterConferenceCall(call: OpaquePointer) {
        os_log("CallingView : Press enter conference", log: log_app_debug, type: .debug)
        // Add a call to conference using conference call cell
        sipUAManager.addCallToConference(call: call)
    }
}


// MARK: - Extension for table view (PauseCallTable, SelectPauseCallTable, ConferenceCallTable)
extension CallingView: UITableViewDelegate , UITableViewDataSource {
    
    // Set a number of row
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Set number of row using number of conference call count
        if toClass == AppView.ClassName.ConferenceCall {
            if tableView == conferenceCallSubView.conferenceCallTable {
                os_log("CallingView : Conference call number : %i", log: log_app_debug, type: .debug, conferenceCallArray.count)
                return conferenceCallArray.count
            } else {
                os_log("CallingView : Pause call number : %i", log: log_app_debug, type: .debug, pauseCallArray.count)
                return pauseCallArray.count
            }
            // Set number of row using number of pause call in array
        } else if toClass == AppView.ClassName.IncomingCall || toClass == AppView.ClassName.OutgoingCall {
            os_log("CallingView : Pause call in array : %i", log: log_app_debug, type: .debug, pauseCallArray.count)
            return pauseCallArray.count
        } else {
            return 0
        }
    }
    
    // Load table cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Declare cell identifier
        let pauseCallCellIdentifier = AppViewCell.Identifier.PauseCallCell
        let selectPauseCallCellIdentifier = AppViewCell.Identifier.SelectPauseCallCell
        let conferenceCallCellIdentifier = AppViewCell.Identifier.ConferenceCallCell
        let conferencePauseCallCellIdentifier = AppViewCell.Identifier.ConferencePauseCallCell
        // Cell
        var pauseCell: UITableViewCell!
        // Set multi selection disable
        tableView.allowsMultipleSelection = false
        // Set selection disable
        tableView.allowsSelection = false
        // If conference view is showing, the table view is from conference view
        if toClass == AppView.ClassName.ConferenceCall {
            // For conference call table
            if tableView == conferenceCallSubView.conferenceCallTable {
                os_log("CallingView : Showing table is : ConferenceCallTable", log: log_app_debug, type: .debug)
                // If current cell is not exist, Register cell using xib
                if tableView.dequeueReusableCell(withIdentifier: conferenceCallCellIdentifier) == nil {
                    tableView.register(UINib(nibName: conferenceCallCellIdentifier, bundle: nil), forCellReuseIdentifier: conferenceCallCellIdentifier)
                }
                // Load cell
                pauseCell = tableView.dequeueReusableCell(withIdentifier: conferenceCallCellIdentifier)
                // Set no selection style
                pauseCell.selectionStyle = UITableViewCell.SelectionStyle.none
            }
            // For conference pause call table
            if tableView == conferenceCallSubView.pauseCallTable {
                os_log("CallingView : Showing table is : ConferencePauseCallTable", log: log_app_debug, type: .debug)
                // If current cell is not exist, Register cell using xib
                if tableView.dequeueReusableCell(withIdentifier: conferencePauseCallCellIdentifier) == nil {
                    tableView.register(UINib(nibName: conferencePauseCallCellIdentifier, bundle: nil), forCellReuseIdentifier: conferencePauseCallCellIdentifier)
                }
                // Load cell
                pauseCell = tableView.dequeueReusableCell(withIdentifier: conferencePauseCallCellIdentifier)
                // Set no selection style
                pauseCell.selectionStyle = UITableViewCell.SelectionStyle.none
            }
            // If conference view not showing that means video call/audio call is showing
            // Then we can check table view between selectPauseCallTable and pauseCallTable
        } else {
            
            // If the table view that showing for selecting pause call to attended transfer
            if tableView == selectPauseCtable {
                os_log("CallingView : Showing table is : SelectPauseCallTable", log: log_app_debug, type: .debug)
                // Set selection enable
                tableView.allowsSelection = true
                // If current cell is not exist, Register cell using xib
                if tableView.dequeueReusableCell(withIdentifier: selectPauseCallCellIdentifier) == nil {
                    tableView.register(UINib(nibName: selectPauseCallCellIdentifier, bundle: nil), forCellReuseIdentifier: selectPauseCallCellIdentifier)
                }
                // Load cell
                pauseCell = tableView.dequeueReusableCell(withIdentifier: selectPauseCallCellIdentifier)
                // Set selection color and style
                pauseCell.selectionStyle = UITableViewCell.SelectionStyle.default
                let customColorView = UIView()
                customColorView.backgroundColor = UIColor.lightGray
                pauseCell.selectedBackgroundView = customColorView
                
                // If the table view that showing for resuming call
            } else {
                os_log("CallingView : Showing table is : PauseCallTable", log: log_app_debug, type: .debug)
                // If current cell is not exist, Register cell using xib
                if tableView.dequeueReusableCell(withIdentifier: pauseCallCellIdentifier) == nil {
                    tableView.register(UINib(nibName: pauseCallCellIdentifier, bundle: nil), forCellReuseIdentifier: pauseCallCellIdentifier)
                }
                // Load cell
                pauseCell = tableView.dequeueReusableCell(withIdentifier: pauseCallCellIdentifier)
                // Set no selection style
                pauseCell.selectionStyle = UITableViewCell.SelectionStyle.none
            }
        }
        
        // Set cornor and mask to crop the bound with round corner for customColorView
        pauseCell.layer.cornerRadius = 5
        pauseCell.layer.masksToBounds = true
        
        // Return to a table view
        return pauseCell
    }
    
    // Set cell data before cell show
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // If conference view is showing
        if toClass == AppView.ClassName.ConferenceCall {
            if tableView == conferenceCallSubView.conferenceCallTable {
                // Prevent index out of bound
                // If there is some conference call in array, Then set data
                if conferenceCallArray.count != 0 {
                    os_log("CallingView : Showing table is : ConferenceCallTable", log: log_app_debug, type: .debug)
                    let myCell = cell as! ConferenceCallCell
                    let conferenceCallData = conferenceCallArray[indexPath.row]
                    myCell.setConferenceCallCell(data: conferenceCallData)
                    myCell.delegate = self
                }
            }
            if tableView == conferenceCallSubView.pauseCallTable {
                // Prevent index out of bound
                // If there is some pause call in array, Then set data
                if pauseCallArray.count != 0 {
                    os_log("CallingView : Showing table is : ConferencePauseCallTable", log: log_app_debug, type: .debug)
                    let myCell = cell as! ConferencePauseCallCell
                    let conferencePauseCallData = pauseCallArray[indexPath.row]
                    myCell.setConferencePauseCallCell(data: conferencePauseCallData)
                    myCell.delegate = self
                }
            }
            // If conference view is not showing, it might be a audio view/video view
        } else {
            // Prevent index out of bound
            // If there is some pause call in array, Then set data
            if pauseCallArray.count != 0 {
                if tableView == selectPauseCtable {
                    os_log("CallingView : Showing table is : SelectPauseCallTable", log: log_app_debug, type: .debug)
                    let myCell = cell as! SelectPauseCell
                    let pauseCallData = pauseCallArray[indexPath.row]
                    myCell.setSelectPauseCallCell(data: pauseCallData)
                } else {
                    os_log("CallingView : Showing table is : PauseCallTable", log: log_app_debug, type: .debug)
                    let myCell = cell as! PauseCallCell
                    let pauseCallData = pauseCallArray[indexPath.row]
                    myCell.setPauseCallCell(data: pauseCallData)
                    myCell.delegate = self
                }
            }
        }
    }
    
    // Set cell height
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    // Set number of section
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    // Temporary keep select pause call data to use in attended transfer call
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == selectPauseCtable {
            tmpSelectPauseCall = pauseCallArray[indexPath.row]
        }
    }
    
}
