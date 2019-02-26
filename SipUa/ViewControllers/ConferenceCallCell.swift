//
//  ConferenceCallCell.swift
//  SipUa
//
//  Created by NLDeviOS on 20/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import SipUAFramwork
import LinphoneModule

// Protocol to implement for a class to leave a conference
protocol ConferenceCallCellDelegate {
    func tapLeaveConferenceCall(call: OpaquePointer)
}

class ConferenceCallCell: UITableViewCell {

    
    @IBOutlet weak var conferenceUsername: UILabel!
    @IBOutlet weak var conferenceID: UILabel!
    @IBOutlet weak var conferenceTime: UILabel!
    @IBOutlet weak var conferenceRemoveBtn: UIButton!
    
    private var conferenceCall: OpaquePointer!
    // Call timer
    private var callTimer: Timer?
    // Use for a class to set a delegate to self
    public var delegate: ConferenceCallCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setConferenceCallCell(data: CallData) {
        conferenceCall = data.call
        if let remoteDisplayName = sipUAManager.getRemoteDisplayName(call: data.call) {
            conferenceUsername.text = remoteDisplayName
        } else {
            conferenceUsername.text = sipUAManager.getRemoteUsername(call: data.call)
        }
        conferenceID.text = data.callID! + " : " + SipUtils.callStateToString(callState: sipUAManager.getStateOfCall(call: data.call))
        conferenceTime.text = "00:00"
        if callTimer == nil {
            os_log("Conference call cell : Start call duration", log: log_app_debug, type: .debug)
            callTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ConferenceCallCell.updateCallDuration), userInfo: nil, repeats: true)
        }
        conferenceRemoveBtn.addTarget(self, action: #selector(removeFromConference), for: .touchUpInside)
    }
    
    func stopCallTimer() {
        if callTimer != nil {
            callTimer?.invalidate()
            callTimer = nil
            conferenceTime.text = "00:00"
            os_log("Conference call cell : Stop call duration", log: log_app_debug, type: .debug)
        }
    }
    
    @objc func updateCallDuration() {
        // If that call is in conference and calling view instance not desetroy
        // To prevent call timer is not stop in sometimes
        if (sipUAManager.checkCallExist(call: conferenceCall) &&
            CallingView.isViewControllerInstanceCreated()) &&
            sipUAManager.isCallInConference(call: conferenceCall) {
            //os_log("Conference call cell : Call cell ID : %@", log: log_app_debug, type: .debug, conferenceCallID)
            conferenceTime.text = sipUAManager.getCallDurationUpdate(call: conferenceCall)
            //os_log("Conference call cell : Call cell duration : %@", log: log_app_debug, type: .debug, conferenceTime.text!)
        } else {
            stopCallTimer()
            return
        }
    }
    
    @objc func removeFromConference() {
        // When tap leave conference call in cell it will order the class that implement a protocol and set delegate to do things
        delegate?.tapLeaveConferenceCall(call: conferenceCall)
        // Stop update call duration
        stopCallTimer()
    }
    
}
