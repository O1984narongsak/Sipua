
import AVFoundation
import LinphoneModule
import CoreBluetooth

// MARK: - Global instance
/**
 Get SipUABluetoothManager instance (a compute property).
 */
internal var SipBluetoothManager: SipUABluetoothManager {
    if SipUABluetoothManager.sipUABluetoothManagerInstance == nil {
        SipUABluetoothManager.sipUABluetoothManagerInstance = SipUABluetoothManager()
    }
    return SipUABluetoothManager.sipUABluetoothManagerInstance!
}

// MARK: - Main class
/**
 SipUABluetoothManager is a class that contain all function about routing to bluetooth.
 */
internal class SipUABluetoothManager : NSObject, CBCentralManagerDelegate {

    // MARK: - Properties
    // Singleton (The static instance).
    fileprivate static var sipUABluetoothManagerInstance: SipUABluetoothManager?
    
    // Bluetooth connected status.
    public static var bluetoothConnected: Bool = false
    
    // Bluetooth input status.
    public static var bluetoothEnabled: Bool = false
    
    // A peripheral device manager to listen a connecting changed.
    let manager: CBCentralManager!
    
    // MARK: - Class initialize
    override init() {
        // Create a central manager with option for not showing turn on bluetooth popup.
        let option = [CBCentralManagerOptionShowPowerAlertKey: false]
        manager = CBCentralManager(delegate: nil, queue: nil, options: option)
        super.init()
        // Set delegate for a central manager.
        manager.delegate = self
    }
    
    // MARK: - Input device
    /**
     Get bluetooth input that is available on device.
     - returns: a audio session port description.
     */
    public func getBluetoothDevice() -> AVAudioSessionPortDescription? {
        if let foundBlueTooth = SipAudioManager.searchAvailableInputDevice(types: allBluetoothType()) {
            return foundBlueTooth
        }
        return nil
    }
    
    /**
     Get all bluetooth type.
     - returns: an array of all bluetooth type in string.
     */
    public func allBluetoothType() -> [String] {
        return [AVAudioSession.Port.bluetoothLE.rawValue, AVAudioSession.Port.bluetoothHFP.rawValue, AVAudioSession.Port.bluetoothA2DP.rawValue]
    }
    
    // MARK: - Route audio session
    /**
     Set input microphone to microphone on bluetooth.
     */
    public func routeAudioToBluetooth() {
        // If connection is really gone.
        if !SipUABluetoothManager.bluetoothConnected || getBluetoothDevice() == nil {
            os_log("Bluetooth not connected or Not found bluetooth input", log: log_manager_error, type: .error)
            return
        }
        // In case a gap between switching audio route, The current input will be empty,
        // If it's empty. input[0] will crash. We will check is bluetooth input set to prevent calling function repeat.
        if !AVAudioSession.sharedInstance().currentRoute.inputs.isEmpty
            && allBluetoothType().contains(AVAudioSession.sharedInstance().currentRoute.inputs[0].portType.rawValue) {
            os_log("Bluetooth input is already set", log: log_manager_debug, type: .debug)
            return
        }
        do {
            os_log("Route to bluetooth...", log: log_manager_debug, type: .debug)
            // Set input, mode following call state.
            if SipAudioManager.callState == LinphoneCallStateStreamsRunning {
                try AVAudioSession.sharedInstance().setMode(AVAudioSession.Mode.voiceChat)
            }
            try AVAudioSession.sharedInstance().setPreferredInput(getBluetoothDevice())
        } catch {
            SipUABluetoothManager.bluetoothEnabled = false
            os_log("Can't enable bluetooth with reason : %@", log: log_manager_error, type: .error, error as CVarArg)
            return
        }
        // Post output device status notification.
        SipAudioManager.postBluetoothNotification()
        SipAudioManager.postHeadphonesNotification()
        SipAudioManager.postSpeakerNotification()
    }
    
    // MARK: - An external audio device connection changed status.
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            os_log("Peripheral is : On", log: log_manager_debug, type: .debug)
            // Set peripheral status to use to set connected bluetooth status.
            SipAudioManager.isPeripheralEnabled = true
            // Check all status.
            SipAudioManager.connectedStatus()
            // See default audio session setting.
            SipAudioManager.checkAudioSession()
            // Post output device status notification.
            SipAudioManager.postBluetoothNotification()
            SipAudioManager.postHeadphonesNotification()
            SipAudioManager.postSpeakerNotification()
        case .poweredOff:
            os_log("Peripheral is : Off", log: log_manager_debug, type: .debug)
            // Set peripheral status to use to set connected bluetooth status.
            SipAudioManager.isPeripheralEnabled = false
            // Check all status.
            SipAudioManager.connectedStatus()
            // See default audio session setting.
            SipAudioManager.checkAudioSession()
            // Post output device status notification.
            SipAudioManager.postBluetoothNotification()
            SipAudioManager.postHeadphonesNotification()
            SipAudioManager.postSpeakerNotification()
        case .resetting:
            os_log("Peripheral is : Resetting", log: log_manager_debug, type: .debug)
        case .unauthorized:
            os_log("Peripheral is : Unauthorized", log: log_manager_debug, type: .debug)
        case .unknown:
            os_log("Peripheral is : Unknown", log: log_manager_debug, type: .debug)
        case .unsupported:
            os_log("Peripheral is : Unsupported", log: log_manager_debug, type: .debug)
        }
    }
    
}
