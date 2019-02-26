//
//  SelectPauseCell.swift
//  SipUa
//
//  Created by NLDeviOS on 21/2/2562 BE.
//  Copyright © 2562 NLDeviOS. All rights reserved.
//

import UIKit
import SipUAFramwork
import LinphoneModule

class SelectPauseCell: UITableViewCell {
    
    @IBOutlet weak var selectPauseUsername: UILabel!
    @IBOutlet weak var selectPauseID: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    
      
        
    }
    
    func setSelectPauseCallCell(data: CallData) {
        if let remoteDisplayName = sipUAManager.getRemoteDisplayName(call: data.call) {
            selectPauseUsername.text = remoteDisplayName
        } else {
            selectPauseUsername.text = sipUAManager.getRemoteUsername(call: data.call)
        }
        selectPauseID.text = data.callID! + " : " + SipUtils.callStateToString(callState: sipUAManager.getStateOfCall(call: data.call))
    }
    
}
