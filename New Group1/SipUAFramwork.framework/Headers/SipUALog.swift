
import LinphoneModule
import os.log

// MARK: - Global log type
public let log_manager_error = OSLog.init(subsystem: "Library.SipUAManager", category: "SIPUA_ERROR")
public let log_manager_debug = OSLog.init(subsystem: "Library.SipUAManager", category: "SIPUA_DEBUG")
public let log_app_error = OSLog.init(subsystem: "Appliaction.App", category: "APP_ERROR")
public let log_app_debug = OSLog.init(subsystem: "Application.App", category: "APP_DEBUG")

// MARK: - Global instance
/**
 Get SipUALog instance (a compute property).
 */
internal var SipLog: SipUALog {
    if SipUALog.sipUALogInstance == nil {
        SipUALog.sipUALogInstance = SipUALog()
    }
    return SipUALog.sipUALogInstance!
}



// MARK: - Main class
/**
 SipUALog is a class that contain all function about linphone log.
 */
internal class SipUALog {

    // MARK: Properties
    // Singleton (The static instance).
    fileprivate static var sipUALogInstance: SipUALog?
    
    // MARK: - Log function
    /* Linphone log handler */
    // If running on simulator.
#if arch(i386) || arch(x86_64)
    let linphone_iphone_log_handler: BctbxLogFunc = {
        (domain: Optional<UnsafePointer<Int8>>, lev: BctbxLogLevel, fmt: Optional<UnsafePointer<Int8>>, args: CVaListPointer) in
        var format: String = String(cString: fmt!)
        var formatedString: String = NSString(format: format, arguments: args) as String
        var lvl: String = ""
        if domain != nil {
            os_log("Log domain : %@", String(cString: domain!))
            // domain = ("lib" as NSString).cString(using: String.Encoding.utf8.rawValue)
        }
        // since \r are interpreted like \n, avoid double new lines when logging network packets (belle-sip)
        // output format is like: I/ios/some logs. We truncate domain to **exactly** DOMAIN_SIZE characters to have
        // fixed-length aligned logs
        switch lev {
        case BCTBX_LOG_FATAL:
            lvl = "Fatal"
            break
        case BCTBX_LOG_ERROR:
            lvl = "Error"
            break
        case BCTBX_LOG_WARNING:
            lvl = "Warning"
            break;
        case BCTBX_LOG_MESSAGE:
            lvl = "Message"
            break;
        case BCTBX_LOG_DEBUG:
            lvl = "Debug"
            break;
        case BCTBX_LOG_TRACE:
            lvl = "Trace"
            break;
        case BCTBX_LOG_LOGLEV_END:
            os_log("Log Level End")
            return
        default:
            os_log("Unknow Log Level")
            return
        }
        if formatedString.contains("\n") {
            var myWords: [String] = formatedString.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
            for i in 0 ..< myWords.count {
                var tab: String = i > 0 ? "\t" : ""
                if myWords[i].count > 0 {
                    os_log("[%@] %@%@", lvl, tab, myWords[i]);
                }
            }
        } else {
            os_log("[%@] %@", lvl, formatedString.replacingOccurrences(of: "\r\n", with: "\n"));
        }
    }
    
    /**
     Enable linphone log.
     - parameters:
     - level: a linphone BctbxLogLevel.
     */
    public func enableLogs(level: BctbxLogLevel) {
        let enabled: Bool = (level.rawValue >= BCTBX_LOG_DEBUG.rawValue && level.rawValue < BCTBX_LOG_ERROR.rawValue)
        var stderrInUse: Bool = false
        if !stderrInUse {
            asl_add_log_file(nil, STDERR_FILENO)
            stderrInUse = true
        }
        let cachePt = cacheDirectory().stringToUnsafePointerInt8()
        linphone_core_set_log_collection_path(cachePt!)
        linphone_core_set_log_handler(linphone_iphone_log_handler)
        if enabled {
            linphone_core_enable_log_collection(LinphoneLogCollectionEnabled)
        } else {
            linphone_core_enable_log_collection(LinphoneLogCollectionDisabled)
        }
        if (level.rawValue == 0) {
            linphone_core_set_log_level(BCTBX_LOG_FATAL)
            bctbx_set_log_level("ios", BCTBX_LOG_FATAL)
            os_log("I/%@/Disabling all logs", ORTP_LOG_DOMAIN)
        } else {
            os_log("I/%@/Enabling %@ logs", ORTP_LOG_DOMAIN, (enabled ? "all" : "application only"))
            linphone_core_set_log_level(level)
            bctbx_set_log_level("ios", level == BCTBX_LOG_DEBUG ? BCTBX_LOG_DEBUG : BCTBX_LOG_MESSAGE)
        }
    }
    // If running on device.
#else
    let linphone_iphone_log_handler: BctbxLogFunc = {
        (domain: Optional<UnsafePointer<Int8>>, lev: BctbxLogLevel, fmt: Optional<UnsafePointer<Int8>>, args: Optional<CVaListPointer>) in
        var format: String = String(cString: fmt!)
        var formatedString: String = NSString(format: format, arguments: args!) as String
        var lvl: String = ""
        if domain != nil {
            os_log("Log domain : %@", String(cString: domain!))
            // domain = ("lib" as NSString).cString(using: String.Encoding.utf8.rawValue)
        }
        // since \r are interpreted like \n, avoid double new lines when logging network packets (belle-sip)
        // output format is like: I/ios/some logs. We truncate domain to **exactly** DOMAIN_SIZE characters to have
        // fixed-length aligned logs
        switch lev {
        case BCTBX_LOG_FATAL:
            lvl = "Fatal"
            break
        case BCTBX_LOG_ERROR:
            lvl = "Error"
            break
        case BCTBX_LOG_WARNING:
            lvl = "Warning"
            break;
        case BCTBX_LOG_MESSAGE:
            lvl = "Message"
            break;
        case BCTBX_LOG_DEBUG:
            lvl = "Debug"
            break;
        case BCTBX_LOG_TRACE:
            lvl = "Trace"
            break;
        case BCTBX_LOG_LOGLEV_END:
            os_log("Log Level End")
            return
        default:
            os_log("Unknow Log Level")
            return
        }
        if formatedString.contains("\n") {
            var myWords: [String] = formatedString.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
            for i in 0 ..< myWords.count {
                var tab: String = i > 0 ? "\t" : ""
                if myWords[i].count > 0 {
                    os_log("[%@] %@%@", lvl, tab, myWords[i]);
                }
            }
        } else {
            os_log("[%@] %@", lvl, formatedString.replacingOccurrences(of: "\r\n", with: "\n"));
        }
    }
    
    /**
     Enable linphone log.
     - parameters:
     - level: a linphone BctbxLogLevel.
     */
    public func enableLogs(level: BctbxLogLevel) {
        let enabled: Bool = (level.rawValue >= BCTBX_LOG_DEBUG.rawValue && level.rawValue < BCTBX_LOG_ERROR.rawValue)
        var stderrInUse: Bool = false
        if !stderrInUse {
            asl_add_log_file(nil, STDERR_FILENO)
            stderrInUse = true
        }
        let cachePt = cacheDirectory().stringToUnsafePointerInt8()
        linphone_core_set_log_collection_path(cachePt!)
        linphone_core_set_log_handler(linphone_iphone_log_handler)
        if enabled {
            linphone_core_enable_log_collection(LinphoneLogCollectionEnabled)
        } else {
            linphone_core_enable_log_collection(LinphoneLogCollectionDisabled)
        }
        if (level.rawValue == 0) {
            linphone_core_set_log_level(BCTBX_LOG_FATAL)
            bctbx_set_log_level("ios", BCTBX_LOG_FATAL)
            os_log("I/%@/Disabling all logs", ORTP_LOG_DOMAIN)
        } else {
            os_log("I/%@/Enabling %@ logs", ORTP_LOG_DOMAIN, (enabled ? "all" : "application only"))
            linphone_core_set_log_level(level)
            bctbx_set_log_level("ios", level == BCTBX_LOG_DEBUG ? BCTBX_LOG_DEBUG : BCTBX_LOG_MESSAGE)
        }
    }
#endif
    
    // MARK: - Cache path
    /* Get cache path */
    fileprivate func cacheDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let cachePath = paths[0]
        var isDir: ObjCBool = false
        let fileManager = FileManager.default
        if !(fileManager.fileExists(atPath: cachePath, isDirectory: &isDir)) && isDir.boolValue == false {
            do {
                try fileManager.createDirectory(atPath: cachePath, withIntermediateDirectories: false, attributes: nil)
                os_log("Cache path is created")
            } catch {
                os_log("Create cache directory => Error : %@", error as CVarArg)
            }
            
        }
        os_log("Cache Path : %@", cachePath)
        return cachePath
    }

}
