//
//  PauseCallCell.swift
//  SipUa
//
//  Created by NLDeviOS on 21/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import SipUAFramwork
import LinphoneModule

// Protocol to implement for a class to resume a call
protocol PauseCallCellDelegate {
    func tapResumeCall(call: OpaquePointer)
}

class PauseCallCell: UITableViewCell {
    
    @IBOutlet weak var pauseUsername: UILabel!
    @IBOutlet weak var pauseTime: UILabel!
    @IBOutlet weak var pauseID: UILabel!
    @IBOutlet weak var resumeCallBtn: UIButton!
    
    // Properties to keep call for resuming
    private var pauseCall: OpaquePointer?
    // Call time
    private var callTimer: Timer?
    // Use for a class to set a delegate to self
    public var delegate: PauseCallCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setPauseCallCell(data: CallData) {
        pauseCall = data.call
        if let remoteDisplayName = sipUAManager.getRemoteDisplayName(call: data.call) {
            pauseUsername.text = remoteDisplayName
        } else {
            pauseUsername.text = sipUAManager.getRemoteUsername(call: data.call)
        }
        pauseID.text = data.callID! + " : " + SipUtils.callStateToString(callState: sipUAManager.getStateOfCall(call: data.call))
        pauseTime.text = "00:00"
        if callTimer == nil {
            os_log("Pause call cell : Start call duration", log: log_app_debug, type: .debug)
            callTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(PauseCallCell.updateCallDuration), userInfo: nil, repeats: true)
        }
        resumeCallBtn.addTarget(self, action: #selector(resumeCall), for: .touchUpInside)
    }
    
    func stopCallTimer() {
        if callTimer != nil {
            callTimer?.invalidate()
            callTimer = nil
            pauseTime.text = "00:00"
            os_log("Pause call cell : Stop call duration", log: log_app_debug, type: .debug)
        }
    }
    
    @objc func updateCallDuration() {
        if (sipUAManager.checkCallExist(call: pauseCall!) &&
            CallingView.isViewControllerInstanceCreated()) &&
            (sipUAManager.getStateOfCall(call: pauseCall) == LinphoneCallStatePaused ||
                sipUAManager.getStateOfCall(call: pauseCall) == LinphoneCallStatePausing ||
                sipUAManager.getStateOfCall(call: pauseCall) == LinphoneCallStatePausedByRemote) {
            //os_log("Pause call cell : Call cell ID : %@", log: log_app_debug, type: .debug, pauseCallID!)
            pauseTime.text = sipUAManager.getCallDurationUpdate(call: pauseCall)
            //os_log("Pause call cell : Call cell duration : %@", log: log_app_debug, type: .debug, pauseTime.text!)
        } else {
            stopCallTimer()
            return
        }
    }
    
    @objc func resumeCall() {
        // When tap resume call in cell it will order the class that implement a protocol and set delegate to do things
        delegate?.tapResumeCall(call: pauseCall!)
        // Stop update call duration
        stopCallTimer()
    }
    
}
