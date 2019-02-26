
import LinphoneModule
import CoreTelephony
import SystemConfiguration

// MARK: - Global instance
/**
 Get SipUANetworkManager instance (a compute property).
 */
internal var SipNetworkManager: SipUANetworkManager {
    if SipUANetworkManager.sipUANetworkManagerInstance == nil {
        SipUANetworkManager.sipUANetworkManagerInstance = SipUANetworkManager()
    }
    return SipUANetworkManager.sipUANetworkManagerInstance!
}

// MARK: - Main class
/**
 SipUANetworkManager is a class that contain all function about connection.
 */
internal class SipUANetworkManager {
    
    // MARK: Properties
    // Singleton (The static instance).
    fileprivate static var sipUANetworkManagerInstance: SipUANetworkManager?
    
    // MARK: - Connection
    /**
     Check a connection type and network reachable.
     - returns:
     
        true, If a connection is fast.
     
        false, If a connection is slow.
     */
    public func isHighBandwidthConnection() -> Bool {
        return (((linphone_core_is_network_reachable(LC) as NSNumber).boolValue) && isConnectionFast())
    }
    
    /* Check connection type */
    private func isConnectionFast() -> Bool {
        
        // Get phone network info.
        let info = CTTelephonyNetworkInfo()
        
        // Get current network info detail.
        let currentRadio = info.currentRadioAccessTechnology
        
        // Check network.
        if currentRadio == CTRadioAccessTechnologyEdge ||
            currentRadio == CTRadioAccessTechnologyGPRS ||
            currentRadio == CTRadioAccessTechnologyCDMA1x {
            os_log("Network type is 2G", log: log_manager_debug, type: .debug)
            return false
        } else if currentRadio == CTRadioAccessTechnologyLTE {
            os_log("Network type is 4G", log: log_manager_debug, type: .debug)
            return true
        } else {
            os_log("Network type is 3G", log: log_manager_debug, type: .debug)
            return true
        }
    }
    
    /**
     Get wifi name that connected.
     - returns: a wifi name as string.
     */
    public func getCurrentWifiSSID() -> String {
        
        // Not support in simulator.
        if Platform.isSimulator {
            os_log("SSID Not support for simulator", log: log_manager_debug, type: .debug)
            return "SSID Not support for simulator"
        } else {
            var data: String = ""
            // Get network info.
            let cfDic = CNCopyCurrentNetworkInfo("en0" as CFString)
            if cfDic != nil {
                if let tmpDic = cfDic as? [String:Any] {
                    os_log("Access Point Wifi Info : %@", log: log_manager_debug, type: .debug, tmpDic)
                    let ssid = "SSID"
                    // Get SSID value.
                    data = tmpDic[ssid] as! String
                }
            }
            os_log("Current Wifi SSID : %@", log: log_manager_debug, type: .debug, data)
            return data
        }
        
    }
}
