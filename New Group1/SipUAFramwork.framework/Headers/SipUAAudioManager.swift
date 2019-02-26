
import AVFoundation
import LinphoneModule

/*
Note.
 - Output will automatically change by connected device, We can set only input to match with output.
 - we can set output to speaker using overriding only.
 - connection status will show that what is current output connected.
 - enable status will show that the input of the current output is set.
 - output and input must be match.
*/

// MARK: - Global instance
/**
 Get SipUAAudioManager instance (a compute property).
 */
internal var SipAudioManager: SipUAAudioManager {
    if SipUAAudioManager.sipUAAudioManagerInstance == nil {
        SipUAAudioManager.sipUAAudioManagerInstance = SipUAAudioManager()
    }
    return SipUAAudioManager.sipUAAudioManagerInstance!
}

// MARK: - Enumeration Audio codec list
/**
 A custom enumerations of audio codec.
 - parameters:
    - OPUS: a opus audio codec.
    - SPEEX: a speex audio codec.
    - PCMU: a PCMU audio codec.
    - PCMA: a PCMA audio codec.
    - GSM: a GSM audio codec.
    - G722: a G722 audio codec.
    - ILBC: a iLBC audio codec.
    - AMR_WB: a AMR-WB audio codec.
    - G729: a G729 audio codec.
    - MPEG4_GENERIC: a mpeg4-generic audio codec.
    - ISAC: a iSAC audio codec.
    - L16: a L16 audio codec.
    - SILK: a SILK audio codec.
    - AMR: a AMR audio codec.
    - BV16: a BV16 audio codec.
 */
internal enum AudioCodecList: String {
    case OPUS = "opus"
    case SPEEX = "speex"
    case PCMU = "PCMU"
    case PCMA = "PCMA"
    case GSM = "GSM"
    case G722 = "G722"
    case ILBC = "iLBC"
    case AMR_WB = "AMR-WB"
    case G729 = "G729"
    case MPEG4_GENERIC = "mpeg4-generic"
    case ISAC = "iSAC"
    case L16 = "L16"
    case SILK = "SILK"
    case AMR = "AMR"
    case BV16 = "BV16"
}

// MARK: - Main class
/**
 SipUAAudioManager is a class that contain all function about audio.
 */
internal class SipUAAudioManager {
    
    // MARK: - Properties
    // Singleton (The static instance).
    fileprivate static var sipUAAudioManagerInstance: SipUAAudioManager?
    
    // Speaker status.
    public static var speakerEnabled: Bool = false
    
    // Headphones connected status.
    public static var headphonesConnected: Bool = false
    // Headphones input status.
    public static var headphonesEnabled: Bool = false
    
    // Call state.
    public var callState: LinphoneCallState!
    
    // Peripheral status using for bluetooth connected status (for now).
    public var isPeripheralEnabled: Bool = false
    
    
    // MARK: - Configuration audio session
    /**
     Set default audio configuration.
     */
    public func config() {
        os_log("Config audio session first run...", log: log_manager_debug, type: .debug)
        
        // Restart audio session for first time.
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            os_log("Can't restart audio session : %@", log: log_manager_error, type: .error, error.localizedDescription)
        }
        
        // See default audio session setting.
        checkAudioSession()
        
        // If set category it will call category change in notification.
        // If set category to PlayAndRecord, default input = MicrophoneBuiltIn, default output = Receiver.
        // If bluetooth device is connected and category is PlayAndRecord, default input = Bluetooth, default output = Bluetooth.
        // If headphones device is connected and category is PlayAndRecord, default input = HandsetWired, default output = Headphones.
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.default, options: AVAudioSession.CategoryOptions.allowBluetooth)
        } catch {
            os_log("Can't set audio session category : %@", log: log_manager_error, type: .error, error.localizedDescription)
        }
        do {
            try AVAudioSession.sharedInstance().setPreferredSampleRate(44100.0)
        } catch {
            os_log("Can't set audio session sample rate : %@", log: log_manager_error, type: .error, error.localizedDescription)
        }
        // Check connection device status.
        connectedStatus()
        
        // See default audio session setting.
        checkAudioSession()
        
        // Post output device status notification.
        postBluetoothNotification()
        postHeadphonesNotification()
        postSpeakerNotification()
    }
    
    /**
     Check default audio configuration.
     */
    public func checkAudioSession() {
        let AudioManager = AVAudioSession.sharedInstance()
        os_log("Default category : %@", log: log_manager_debug, type: .debug, AudioManager.category.rawValue)
        os_log("Default mode : %@", log: log_manager_debug, type: .debug, AudioManager.mode.rawValue)
        os_log("Default current input : %@", log: log_manager_debug, type: .debug, AudioManager.currentRoute.inputs)
        os_log("Default current output : %@", log: log_manager_debug, type: .debug, AudioManager.currentRoute.outputs)
        os_log("Default preferred input : %@", log: log_manager_debug, type: .debug, AudioManager.preferredInput ?? "nil")
        os_log("Default available input : %@", log: log_manager_debug, type: .debug, AudioManager.availableInputs ?? "nil")
    }
    
    /**
     Restart audio session.
     */
    public func restartAudioSession() {
        os_log("Restart audio session", log: log_manager_debug, type: .debug)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.default, options: AVAudioSession.CategoryOptions.allowBluetooth)
            try AVAudioSession.sharedInstance().setPreferredSampleRate(44100.0)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            os_log("Can't restart audio session with reason : %@", log: log_manager_error, type: .error, error as CVarArg)
            return
        }
        // Check connect device status.
        SipAudioManager.connectedStatus()
    }
    
    // MARK: - Check device status
    /**
     Check all audio device connected or enabled status.
     */
    public func connectedStatus() {
        os_log("Check all input/output status", log: log_manager_debug, type: .debug)
        let AudioManager = AVAudioSession.sharedInstance()
        let route = AudioManager.currentRoute
        
        // ================ Check output ================ //
        // Check bluetooth output connection.
        if route.outputs.count != 0 {
            if SipBluetoothManager.allBluetoothType().contains(route.outputs[0].portType.rawValue) {
                SipUABluetoothManager.bluetoothConnected = true
            } else {
                // If current output is not bluetooth.
                // We check available input again to be sure that bluetooth is completely disconnected.
                if SipBluetoothManager.getBluetoothDevice() != nil {
                    if isPeripheralEnabled {
                        SipUABluetoothManager.bluetoothConnected = true
                    } else {
                        SipUABluetoothManager.bluetoothConnected = false
                    }
                } else {
                    SipUABluetoothManager.bluetoothConnected = false
                }
            }
        }
        // Check headphones output connection.
        if route.outputs.count != 0 {
            if route.outputs[0].portType == AVAudioSession.Port.headphones {
                SipUAAudioManager.headphonesConnected = true
            } else {
                // If current output is not headphones.
                // We check available input again to be sure that headphones is completely disconnected.
                if getBuildInHeadphonesDevice() != nil {
                    SipUAAudioManager.headphonesConnected = true
                } else {
                    SipUAAudioManager.headphonesConnected = false
                }
            }
        }
        // Check receiver output connection.
        if route.outputs.count != 0 {
            if route.outputs[0].portType == AVAudioSession.Port.builtInReceiver {
                SipUAAudioManager.speakerEnabled = false
                SipUABluetoothManager.bluetoothEnabled = false
                SipUAAudioManager.headphonesEnabled = false
            }
        }
        // Check speaker status.
        if route.outputs.count != 0 {
            if route.outputs[0].portType == AVAudioSession.Port.builtInSpeaker {
                SipUAAudioManager.speakerEnabled = true
                SipUABluetoothManager.bluetoothEnabled = false
                SipUAAudioManager.headphonesEnabled = false
            } else {
                SipUAAudioManager.speakerEnabled = false
            }
        }
        
        // ================ Check input ================ //
        // Check bluetooth input connection.
        if SipUABluetoothManager.bluetoothConnected {
            // If current input is not empty, It happens sometime.
            if !AudioManager.currentRoute.inputs.isEmpty {
                for connect in AudioManager.currentRoute.inputs {
                    // If input is set.
                    if SipBluetoothManager.allBluetoothType().contains(connect.portType.rawValue) {
                        SipUAAudioManager.speakerEnabled = false
                        SipUABluetoothManager.bluetoothEnabled = true
                        SipUAAudioManager.headphonesEnabled = false
                    } else {
                        SipUABluetoothManager.bluetoothEnabled = false
                    }
                }
            } else {
                SipUABluetoothManager.bluetoothEnabled = false
            }
        } else {
            SipUABluetoothManager.bluetoothEnabled = false
        }
        // Check headphones input connect.
        if SipUAAudioManager.headphonesConnected {
            // If current input is not empty, It happens sometime.
            if !AudioManager.currentRoute.inputs.isEmpty {
                for connect in AudioManager.currentRoute.inputs {
                    // If input is set.
                    if connect.portType == AVAudioSession.Port.headsetMic {
                        SipUAAudioManager.speakerEnabled = false
                        SipUABluetoothManager.bluetoothEnabled = false
                        SipUAAudioManager.headphonesEnabled = true
                    } else {
                        SipUAAudioManager.headphonesEnabled = false
                    }
                }
            } else {
                SipUAAudioManager.headphonesEnabled = false
            }
        } else {
            SipUAAudioManager.headphonesEnabled = false
        }
        
        // See all status.
        os_log("Bluetooth connected : %@", log: log_manager_debug, type: .debug, SipUABluetoothManager.bluetoothConnected ? "true" : "false")
        os_log("Bluetooth enable : %@", log: log_manager_debug, type: .debug, SipUABluetoothManager.bluetoothEnabled ? "true" : "false")
        os_log("Headphones connected : %@", log: log_manager_debug, type: .debug, SipUAAudioManager.headphonesConnected ? "true" : "false")
        os_log("Headphones enable : %@", log: log_manager_debug, type: .debug, SipUAAudioManager.headphonesEnabled ? "true" : "false")
        os_log("Speaker enable  : %@", log: log_manager_debug, type: .debug, SipUAAudioManager.speakerEnabled ? "true" : "false")
        
    }
    
    // MARK: - Route audio session
    /**
     Temporary override output to speaker.
     */
    public func routeAudioToSpeaker() {
        do {
            os_log("Route to speaker...", log: log_manager_debug, type: .debug)
            // Set override output.
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        } catch {
            // In case failed.
            SipUAAudioManager.speakerEnabled = false
            os_log("Can't enable speaker with reason : %@", log: log_manager_error, type: .error, error as CVarArg)
            return
        }
        // Post output device status notification.
        postBluetoothNotification()
        postHeadphonesNotification()
        postSpeakerNotification()
    }
    
    /**
     Cancel override output to speaker and Set input to build-in microphone.
     */
    public func routeAudioToReceiver() {
        // If headphones is connected. We can not set input to build-in microphone,
        // It will cause input = MicrophoneBuiltIn, output = Headphones. That is weird.
        if SipUAAudioManager.headphonesConnected || getBuildInHeadphonesDevice() != nil {
            os_log("Headphones connected and input available, Can not change to receiver...", log: log_manager_debug, type: .debug)
            return
        }
        do {
            os_log("Route to receiver...", log: log_manager_debug, type: .debug)
            // Set input, mode following call state.
            if SipAudioManager.callState == LinphoneCallStateStreamsRunning {
                try AVAudioSession.sharedInstance().setMode(AVAudioSession.Mode.voiceChat)
            }
            try AVAudioSession.sharedInstance().setPreferredInput(getBuildInMicDevice())
        } catch {
            os_log("Can't enable receiver with reason : %@", log: log_manager_error, type: .error, error as CVarArg)
            return
        }
        // Post output device status notification.
        postBluetoothNotification()
        postHeadphonesNotification()
        postSpeakerNotification()
    }
    
    /**
     Set input microphone to build-in microphone headphones.
     */
    public func routeAudioToHeadphones() {
        // If connection is really gone.
        if !SipUAAudioManager.headphonesConnected || getBuildInHeadphonesDevice() == nil {
            os_log("Headphones not connected and Not found headphones input", log: log_manager_error, type: .error)
            return
        }
        // In case a gap between switching audio route, The current input will be empty,
        // If it's empty. input[0] will crash. We will check is headphones input set to prevent calling function repeat.
        if !AVAudioSession.sharedInstance().currentRoute.inputs.isEmpty
            && AVAudioSession.sharedInstance().currentRoute.inputs[0].portType == AVAudioSession.Port.headsetMic {
            os_log("Headphones input is already set", log: log_manager_debug, type: .debug)
            return
        }
        do {
            os_log("Route input to headphones...", log: log_manager_debug, type: .debug)
            // Set input, mode following call state
            if SipAudioManager.callState == LinphoneCallStateStreamsRunning {
                try AVAudioSession.sharedInstance().setMode(AVAudioSession.Mode.voiceChat)
            }
            try AVAudioSession.sharedInstance().setPreferredInput(getBuildInHeadphonesDevice())
        } catch {
            // In case failed.
            SipUAAudioManager.headphonesEnabled = false
            os_log("Can't set input to headphones with reason : %@", log: log_manager_error, type: .error, error as CVarArg)
            return
        }
        // Post output device status notification.
        postBluetoothNotification()
        postHeadphonesNotification()
        postSpeakerNotification()
    }
    
    // MARK: - Audio Mode
    /**
     Set audio mode for voice VoIP.
     */
    public func setAudioManagerInVoiceCallMode() {
        // If audio session is already in voice mode, return.
        if AVAudioSession.sharedInstance().mode == AVAudioSession.Mode.voiceChat {
            os_log("Audio is already in voice mode", log: log_manager_debug, type: .debug)
            return
        }
        do {
            os_log("Audio mode is set to voice mode", log: log_manager_debug, type: .debug)
            // If connect receiver and current out put is receiver. Set mode will do nothing but mode change.
            // If connect receiver and current out put is speaker. Set mode will call category changed,
            //   ---> It will auto change to input = MicrophoneBuiltIn, output = Receiver.
            // If connect with headphones/bluetooth (or receiver) and current out put is speaker/receiver. Set mode will call category change,
            //   ---> It will auto reset input and output to current connected device (headphones/bluetooth) and mode is changed.
            try AVAudioSession.sharedInstance().setMode(AVAudioSession.Mode.voiceChat)
        } catch {
            os_log("Can not set audio mode with reason : %@", log: log_manager_error, type: .error, error as CVarArg)
            return
        }
        // Post output device status notification.
        postBluetoothNotification()
        postHeadphonesNotification()
        postSpeakerNotification()
    }
    
    /**
     Set audio mode to default.
     */
    public func setAudioManagerInDefaultMode() {
        // If audio session is already in default mode, return.
        if AVAudioSession.sharedInstance().mode == AVAudioSession.Mode.default {
            os_log("Audio is already in default mode", log: log_manager_debug, type: .debug)
            return
        }
        do {
            os_log("Audio mode is set to default mode", log: log_manager_debug, type: .debug)
            try AVAudioSession.sharedInstance().setMode(AVAudioSession.Mode.default)
        } catch {
            os_log("Can not set audio mode with reason : %@", log: log_manager_error, type: .error, error as CVarArg)
            return
        }
        // Post output device status notification.
        postBluetoothNotification()
        postHeadphonesNotification()
        postSpeakerNotification()
    }
    
    // MARK: - Notifications
    /**
     Add observer for audio session notification.
     */
    public func registerForAudioRouteChangeNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        // Register notification for call state change.
        registerForCallChangeNotification()
    }
    
    /**
     Remove observer for audio session notification.
     */
    public func deregisterFromAudioRouteChangeNotification() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        // Deregister notification for call state change.
        deregisterForCallChangeNotification()
    }
    
    /* Add observer for call state change notification */
    fileprivate func registerForCallChangeNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateCallState), name: .kLinphoneCallStateUpdate, object: nil)
    }
    
    /* Remove observer for call state change notification */
    fileprivate func deregisterForCallChangeNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateCallState), name: .kLinphoneCallStateUpdate, object: nil)
    }
    
    /**
     Post bluetooth status notification.
     */
    public func postBluetoothNotification() {
        os_log("Post bluetooth notification status : Connected [%@] | Enable [%@] ", log: log_manager_debug, type: .debug, SipUABluetoothManager.bluetoothConnected ? "true" : "false", SipUABluetoothManager.bluetoothEnabled ? "true" : "false")
        let dictionaryBluetooth: [AnyHashable:Any] = ["connected" : SipUABluetoothManager.bluetoothConnected , "enabled" : SipUABluetoothManager.bluetoothEnabled]
        
        // Post notification on main thread.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kBluetoothStateUpdate, object: self, userInfo: dictionaryBluetooth)
        }
    }
    
    /**
     Post headphones status notification.
     */
    public func postHeadphonesNotification() {
        os_log("Post headphones notification status : Connected [%@] | Enable [%@] ", log: log_manager_debug, type: .debug, SipUAAudioManager.headphonesConnected ? "true" : "false", SipUAAudioManager.headphonesEnabled ? "true" : "false")
        let dictionaryHeadphones: [AnyHashable:Any] = ["connected" : SipUAAudioManager.headphonesConnected , "enabled" : SipUAAudioManager.headphonesEnabled]
        
        // Post notification on main thread.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kHeadphonesStateUpdate, object: self, userInfo: dictionaryHeadphones)
        }
    }
    
    /**
     Post speaker status notification.
     */
    public func postSpeakerNotification() {
        os_log("Post speaker notification status : Enable [%@] ", log: log_manager_debug, type: .debug, SipUAAudioManager.speakerEnabled ? "true" : "false")
        let dictionarySpeaker: [AnyHashable:Any] = ["enabled" : SipUAAudioManager.speakerEnabled]
        
        // Post notification on main thread.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .kSpeakerStateUpdate, object: self, userInfo: dictionarySpeaker)
        }
    }

    
    // MARK: - Call state changed
    /* Update call state for automatic set audio mode */
    @objc func updateCallState(notification: Notification) {
        // Cast dictionary value to linphone call state.
        callState = (notification.userInfo!["state"] as! LinphoneCallState)
    }
    
    // MARK: - Input device
    /**
     Get build-in microphone input that is available on device.
     - returns: a audio session port description.
     */
    public func getBuildInMicDevice() -> AVAudioSessionPortDescription? {
        let micBuildIn = [AVAudioSession.Port.builtInMic.rawValue]
        return searchAvailableInputDevice(types: micBuildIn)
    }
    
    /**
     Get build-in microphone headphones input that is available on device.
     - returns: a audio session port description.
     */
    public func getBuildInHeadphonesDevice() -> AVAudioSessionPortDescription? {
        let headphonesBuildIn = [AVAudioSession.Port.headsetMic.rawValue]
        return searchAvailableInputDevice(types: headphonesBuildIn)
    }
    
    /**
     Search all available input on device.
     - parameters:
        - types: an array of audio session port description.
     - returns: a audio session port description.
     */
    public func searchAvailableInputDevice(types: [String]) -> AVAudioSessionPortDescription? {
        // Get all available input ports in device.
        let routes = AVAudioSession.sharedInstance().availableInputs
        os_log("Searching all available input...", log: log_manager_debug, type: .debug)
        // Search each input port with specific input port type.
        for route in routes! {
            if types.contains(route.portType.rawValue) {
                os_log("Found input name : %@", log: log_manager_debug, type: .debug, route.portType as CVarArg)
                return route
            }
        }
        os_log("Not found input name : %@", log: log_manager_debug, type: .debug, types)
        return nil
    }
    
    // MARK: - Audio route change notification
    /* Callback for notification if audio session route change */
    @objc func handleRouteChange(notification: Notification) {
        os_log("Audio route change...", log: log_manager_debug, type: .debug)
        
        // Check notification info for nil.
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let changeReason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else { return }
        
        let oldRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
        var oldOutput: String = ""
        if oldRoute?.outputs.count != 0 {
            oldOutput = (oldRoute?.outputs[0].portType)!.rawValue
        }
        let newRoute = AVAudioSession.sharedInstance().currentRoute
        var newOutput: String = ""
        if newRoute.outputs.count != 0 {
            newOutput = newRoute.outputs[0].portType.rawValue
        }
        
        switch changeReason {
        case .oldDeviceUnavailable:
            os_log("Current device disconnected...", log: log_manager_debug, type: .debug)
            
            // Check all status.
            connectedStatus()
            
            // Disconnect a headphones output.
            if oldOutput == AVAudioSession.Port.headphones.rawValue {
                // Check if bluetooth device connected.
                if SipUABluetoothManager.bluetoothConnected {
                    SipBluetoothManager.routeAudioToBluetooth()
                } else {
                    routeAudioToReceiver()
                }
            // Disconnect a bluetooth output.
            } else if SipBluetoothManager.allBluetoothType().contains(oldOutput) {
                // Check if headphones device connected.
                if SipUAAudioManager.headphonesConnected {
                    routeAudioToHeadphones()
                } else {
                    routeAudioToReceiver()
                }
            }
            
            // Check all status again.
            connectedStatus()
            
        case .newDeviceAvailable:
            os_log("New device connected...", log: log_manager_debug, type: .debug)
            
            // Check all status.
            connectedStatus()
            
            // Connect a headphones output.
            if newOutput == AVAudioSession.Port.headphones.rawValue {
                routeAudioToHeadphones()
            // Connect a bluetooth output.
            } else if SipBluetoothManager.allBluetoothType().contains(newOutput) {
                SipBluetoothManager.routeAudioToBluetooth()
            }
            
            // Check all status again.
            connectedStatus()
            
        case .override:
            os_log("Override device changed...", log: log_manager_debug, type: .debug)
            
            // Check all status.
            connectedStatus()
            
        case .unknown:
            os_log("Unknown changed...", log: log_manager_debug, type: .debug)
        case .categoryChange:
            os_log("Catagory changed...", log: log_manager_debug, type: .debug)
            
            // Check all status.
            connectedStatus()
            
        case .wakeFromSleep:
            os_log("Wake from sleep changed...", log: log_manager_debug, type: .debug)
        case .noSuitableRouteForCategory:
            os_log("No suitable route for category changed...", log: log_manager_debug, type: .debug)
        case .routeConfigurationChange:
            os_log("Route configuration changed...", log: log_manager_debug, type: .debug)
            
            // Check all status.
            connectedStatus()
            
        }
        
        // See default audio session setting.
        checkAudioSession()
        
        // Post output device status notification.
        postBluetoothNotification()
        postHeadphonesNotification()
        postSpeakerNotification()
        
    }
    
    /* Callback for notification if audio session interruption */
    @objc func handleInterruption(notification: Notification) {
        os_log("Audio interrupted...", log: log_manager_debug, type: .debug)
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        // Check interruption type.
        switch type {
        case .began:
            os_log("Began audio interruption...", log: log_manager_debug, type: .debug)
            // Check a call that is running and pause a call.
            let call = linphone_core_get_current_call(LC)
            if call != nil && linphone_call_get_state(call!) == LinphoneCallStateStreamsRunning {
                os_log("Pause running call...", log: log_manager_debug, type: .debug)
                linphone_call_pause(call)
            }
        case .ended:
            os_log("Ended audio interruption...", log: log_manager_debug, type: .debug)
        }
    }
    
    // MARK: - Codecs
    /**
     Search all available audio codec in linphone and add it to SipPayloadType.
     - returns: an array of SipPayloadType.
     */
    public func getAudioCodecs() -> Array<SipPayloadType> {
        
        // Create array of SipPayloadType.
        var allAudioPayloadType: Array<SipPayloadType> = []
        // Get all audio codecs.
        let audioCodecsList = linphone_core_get_audio_payload_types(LC)
        // Access to the memory of audio codecs.
        var audioCodecs = audioCodecsList?.pointee
        
        while audioCodecs != nil {
            // Create SipPayloadType.
            var sipPt = SipPayloadType()
            // Get raw data from memory of audio codecs.
            let audioCodecsData = audioCodecs?.data
            // Add value to SipPayloadType.
            let audioCodecsDataPt = OpaquePointer(audioCodecsData)
            sipPt.name = String(cString: linphone_payload_type_get_mime_type(audioCodecsDataPt))
            sipPt.clock_rate = Int(linphone_payload_type_get_clock_rate(audioCodecsDataPt))
            sipPt.channels = Int(linphone_payload_type_get_channels(audioCodecsDataPt))
            // Add SipPayloadType to array.
            allAudioPayloadType.append(sipPt)
            // If the next memory of audio codec is exist, Move to next codec.
            if (audioCodecs?.next) != nil {
                audioCodecs = audioCodecs?.next.pointee
            } else {
                break
            }
        }
        
        os_log("All audio payload type : %@", log: log_manager_debug, type: .debug, allAudioPayloadType)
        
        return allAudioPayloadType
    }
    
    /* Enable codec in linphone */
    private func enableAudioCodec(name: String, enable: Bool) {
        // Get payload type from name
        if let payloadType = linphone_core_get_payload_type(LC, name.stringToUnsafePointerInt8(), LINPHONE_FIND_PAYLOAD_IGNORE_RATE, LINPHONE_FIND_PAYLOAD_IGNORE_CHANNELS) {
            linphone_payload_type_enable(payloadType, UInt8(enable.intValue))
        }
    }
    
    /**
     Enable specific audio codecs.
     */
    public func enableAudioCodecSet() {
        os_log("=== Enable Audio Codecs ===", log: log_manager_debug, type: .debug)
        for audioPayloadType in getAudioCodecs() {
            if audioPayloadType.name == AudioCodecList.OPUS.rawValue ||
                audioPayloadType.name == AudioCodecList.SILK.rawValue ||
                audioPayloadType.name == AudioCodecList.SPEEX.rawValue ||
                audioPayloadType.name == AudioCodecList.PCMU.rawValue ||
                audioPayloadType.name == AudioCodecList.PCMA.rawValue ||
                audioPayloadType.name == AudioCodecList.G729.rawValue {
                os_log("Enable payload type Name : %@", log: log_manager_debug, type: .debug, audioPayloadType.name)
                enableAudioCodec(name: audioPayloadType.name, enable: true)
            } else {
                enableAudioCodec(name: audioPayloadType.name, enable: false)
            }
        }
    }
}
