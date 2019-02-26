//
//  ConferencePauseCallCell.swift
//  SipUa
//
//  Created by NLDeviOS on 20/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import SipUAFramwork
import LinphoneModule

// Protocol to implement for a class to enter a conference
protocol ConferencePauseCallCellDelegate {
    func tapEnterConferenceCall(call: OpaquePointer)
}

class ConferencePauseCallCell: UITableViewCell {
    
    @IBOutlet weak var conferencePauseUsername: UILabel!
    @IBOutlet weak var conferencePauseID: UILabel!
    @IBOutlet weak var conferencePauseTime: UILabel!
    @IBOutlet weak var conferencePauseAddBtn: UIButton!
    
    // Properties to keep call for enter conference
    private var conferencePauseCall: OpaquePointer?
    
    // Call timer
    private var callTimer: Timer?
    
    // Use for a class to set a delegate to self
    var delegate: ConferencePauseCallCellDelegate?
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setConferencePauseCallCell(data: CallData) {
        conferencePauseCall = data.call
        if let remoteDisplayName = sipUAManager.getRemoteDisplayName(call: data.call) {
            conferencePauseUsername.text = remoteDisplayName
        } else {
            conferencePauseUsername.text = sipUAManager.getRemoteUsername(call: data.call)
        }
        conferencePauseID.text = data.callID! + " : " + SipUtils.callStateToString(callState: sipUAManager.getStateOfCall(call: data.call))
        conferencePauseTime.text = "00:00"
        if callTimer == nil {
            os_log("Conference pause call cell : Start call duration", log: log_app_debug, type: .debug)
            callTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ConferencePauseCallCell.updateCallDuration), userInfo: nil, repeats: true)
        }
        conferencePauseAddBtn.addTarget(self, action: #selector(addToConference), for: .touchUpInside)
    }
    
    func stopCallTimer() {
        if callTimer != nil {
            callTimer?.invalidate()
            callTimer = nil
            conferencePauseTime.text = "00:00"
            os_log("Conference pause call cell : Stop call duration", log: log_app_debug, type: .debug)
        }
    }
    
    @objc func updateCallDuration() {
        if (sipUAManager.checkCallExist(call: conferencePauseCall!) &&
            CallingView.isViewControllerInstanceCreated()) &&
            (sipUAManager.getStateOfCall(call: conferencePauseCall) == LinphoneCallStatePaused ||
                sipUAManager.getStateOfCall(call: conferencePauseCall) == LinphoneCallStatePausing ||
                sipUAManager.getStateOfCall(call: conferencePauseCall) == LinphoneCallStatePausedByRemote) {
            //os_log("Conference pause call cell : Call cell ID : %@", log: log_app_debug, type: .debug, conferencePauseCallID!)
            conferencePauseTime.text = sipUAManager.getCallDurationUpdate(call: conferencePauseCall)
            //os_log("Conference pause call cell : Call cell duration : %@", log: log_app_debug, type: .debug, conferencePauseTime.text!)
        } else {
            stopCallTimer()
            return
        }
    }
    
    @objc func addToConference() {
        // When tap enter conference call in cell it will order the class that implement a protocol and set delegate to do things
        delegate?.tapEnterConferenceCall(call: conferencePauseCall!)
        // Stop update call duration
        stopCallTimer()
    }
    
}
