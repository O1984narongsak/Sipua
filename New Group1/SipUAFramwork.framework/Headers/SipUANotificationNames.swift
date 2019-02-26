//
//  SipUANotificationNames.swift
//  SipUAFramwork
//
//  Created by Sarunyu Prasert on 19/2/2561 BE.
//  Copyright © 2561 Entronica. All rights reserved.
//

import Foundation

// MARK: - Global properties
/* String to post notifications */
extension Notification.Name {
    public static let kLinphoneCoreUpdate =  Notification.Name("LinphoneCoreUpdate")
    public static let kLinphoneGlobalStateUpdate = Notification.Name("LinphoneGlobalStateUpdate")
    public static let kLinphoneConfiguringStateUpdate = Notification.Name("LinphoneConfiguringStateUpdate")
    public static let kLinphoneRegistrationStateUpdate = Notification.Name("LinphoneRegistrationStateUpdate")
    public static let kLinphoneCallStateUpdate = Notification.Name("LinphoneCallStateUpdate")
    public static let kLinphoneMessageReceived = Notification.Name("LinphoneMessageReceived")
    public static let kLinphoneMessageComposeReceived = Notification.Name("LinphoneMessageComposeReceived")
    public static let kLinphoneMessageStateUpdate = Notification.Name("LinphoneMessageStateUpdate")
    public static let kBluetoothStateUpdate = Notification.Name("BluetoothStateUpdate")
    public static let kHeadphonesStateUpdate = Notification.Name("HeadphonesStateUpdate")
    public static let kSpeakerStateUpdate = Notification.Name("SpeakerStateUpdate")
    public static let kMicrophoneStateUpdate = Notification.Name("MicrophoneStateUpdate")
}
