
import LinphoneModule

// MARK: - Global instance
/**
 Get SipUAVideoManager instance (a compute property).
 */
internal var SipVideoManager: SipUAVideoManager {
    if SipUAVideoManager.sipUAVideoManagerInstance == nil {
        SipUAVideoManager.sipUAVideoManagerInstance = SipUAVideoManager()
    }
    return SipUAVideoManager.sipUAVideoManagerInstance!
}

// MARK: - Enumeration Video codec list
/**
 A custom enumerations of video codec.
 - parameters:
    - VP8: a vp8 video codec.
    - H264: a h264 video codec.
 */
internal enum VideoCodecList: String {
    case VP8 = "VP8"
    case H264 = "H264"
}

// MARK: - Main class
/**
 SipUAVideoManager is a class that contain all function about video.
 */
internal class SipUAVideoManager {
    
    // MARK: - Properties
    // Singleton (The static instance).
    fileprivate static var sipUAVideoManagerInstance: SipUAVideoManager?
    
    // View to show or hide while waiting a first video image
    var waitingView: UIActivityIndicatorView?
    
    // MARK: - Closure
    /* Closure for linphone callback function */
    let linphoneVideoCallCb: LinphoneCallCbFunc = { (call: OpaquePointer?, userData: UnsafeMutableRawPointer?) in
        // Get user data(SipUAVideoManager) from linphone, because in closure we can't use SipUAVideoManager directly.
        let userClass = Unmanaged<SipUAVideoManager>.fromOpaque(userData!).takeUnretainedValue()
        // Hide indicator and stop animate
        userClass.waitingView?.isHidden = true
        userClass.waitingView?.stopAnimating()
    }
    
    // MARK: - Codecs
    /**
     Search all available video codec in linphone and add it to SipPayloadType.
     - returns: an array of SipPayloadType.
     */
    public func getVideoCodecs() -> Array<SipPayloadType> {
        
        // Create array of SipPayloadType.
        var allVideoPayloadType: Array<SipPayloadType> = []
        // Get all video codecs.
        let videoCodecsList = linphone_core_get_video_payload_types(LC)
        // Access to the memory of video codecs.
        var videoCodecs = videoCodecsList?.pointee
        
        while videoCodecs != nil {
            // Create SipPayloadType.
            var sipPt = SipPayloadType()
            // Get raw data from memory of video codecs.
            let videoCodecsData = videoCodecs?.data
            // Add value to SipPayloadType.
            let videoCodecsDataPt = OpaquePointer(videoCodecsData)
            sipPt.name = String(cString: linphone_payload_type_get_mime_type(videoCodecsDataPt))
            sipPt.clock_rate = Int(linphone_payload_type_get_clock_rate(videoCodecsDataPt))
            sipPt.channels = Int(linphone_payload_type_get_channels(videoCodecsDataPt))
            // Add SipPayloadType to array.
            allVideoPayloadType.append(sipPt)
            // If the next memory of video codec is exist, Move to next codec.
            if (videoCodecs?.next) != nil {
                videoCodecs = videoCodecs?.next.pointee
            } else {
                break
            }
        }
        
        os_log("All video payload type : %@", log: log_manager_debug, type: .debug, allVideoPayloadType)
        
        return allVideoPayloadType
    }
    
    /* Enable codec in linphone */
    private func enableVideoCodec(name: String, enable: Bool) {
        // Get payload type from name
        if let payloadType = linphone_core_get_payload_type(LC, name.stringToUnsafePointerInt8(), LINPHONE_FIND_PAYLOAD_IGNORE_RATE, LINPHONE_FIND_PAYLOAD_IGNORE_CHANNELS) {
            linphone_payload_type_enable(payloadType, UInt8(enable.intValue))
        }
    }
    
    /**
     Enable specific video codecs.
     */
    public func enableVideoCodecSet() {
        os_log("=== Enable Video Codecs ===", log: log_manager_debug, type: .debug)
        for videoPayloadType in getVideoCodecs() {
            if videoPayloadType.name == VideoCodecList.H264.rawValue {
                os_log("Enable payload type Name : %@", log: log_manager_debug, type: .debug, videoPayloadType.name)
                enableVideoCodec(name: videoPayloadType.name, enable: true)
            } else {
                enableVideoCodec(name: videoPayloadType.name, enable: false)
            }
        }
    }
    
    // MARK: - Call function
    /**
     Use to show or hide a indicator while waiting a first video image.
     - parameters:
        - call: a linphone call.
        - viewToShow: an activity indicator view.
     */
    public func waitingForVideo(call: OpaquePointer, viewToShow: UIActivityIndicatorView) {
        // Set indicator for this class
        waitingView = viewToShow
        // Show indicator and animate
        waitingView?.isHidden = false
        waitingView?.startAnimating()
        // Check video stream codec and set callback when first video image is show
        let currentParam = linphone_call_get_current_params(call)
        if linphone_call_params_get_used_video_payload_type(currentParam) != nil {
            linphone_call_set_next_video_frame_decoded_callback(call, linphoneVideoCallCb, SipUAManager.instance().bridgeRetained(obj: self))
        } else {
            os_log("Video payload type is nil : Do nothing", log: log_manager_error, type: .error)
            return
        }
    }
    
    // MARK: - Video function
    /**
     Check front or back camera is set for default video call.
     - returns:
     
        true, If the current camera is front camera.
     
        false, If the current camera is back camera.
     */
    public func isFrontCamera() -> Bool {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        
        // Get current video device.
        let currentCamID = String(cString: linphone_core_get_video_device(LC))
        os_log("Current camera id : %@", log: log_manager_debug, type: .debug, currentCamID)
        os_log("Current camera is : %@", log: log_manager_debug, type: .debug, (currentCamID == FRONT_CAM_NAME ? "Front Camera" : "Back Camera"))
        if currentCamID == FRONT_CAM_NAME {
            return true
        }
        return false
    }
    
    /**
     Switch a camera between front and back.
     */
    public func switchCamera() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        
        // Get current camera.
        let currentCam = String(cString: linphone_core_get_video_device(LC))
        // Define new camera to switch.
        var newCam: String?
        // Get all camera from linphone.
        let camArray: Array<String> = getVideoDevice()
        
        // Compare current camera with all camera.
        // If match will do nothing / If not match will set new camera to that camera.
        // Compare string.
        // strcmp() - a string compare function.
        // (return 0 if two string is equal, return negative integer if string1 less than string2, return positive integer if string1 greater than string2).
        if !camArray.isEmpty {
            for cam in camArray {
                if strcmp(cam, "StaticImage: Static picture") == 0 {
                    continue
                }
                if strcmp(cam, currentCam) != 0 {
                    newCam = cam
                    break
                }
            }
        }
        
        // Switch camera to new camera.
        if let newCamId = newCam {
            os_log("Switching from [%@] to [%@]", log: log_manager_debug, type: .debug, currentCam, newCamId)
            // Set camera to linphone.
            linphone_core_set_video_device(LC, newCam);
            // Update call.
            SipCallManager.updateCall()
        }
        
    }
    
    /**
     Check a device is supported video or not.
     - returns:
     
        true, If device support video.
     
        false, If device doesn't support video.
     */
    public func isVideoSupported() -> Bool {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        return Int(linphone_core_video_supported(LC)).boolValue
    }
    
    /**
     Set native video window and video preview to linphone for video call.
     - parameters:
        - videoView: the UIView object that will show a remote video view.
        - captureView: the UIView object that will show a capture video view.
     */
    public func createVideoSurface(videoView: UIView?, captureView: UIView?) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        os_log("Clear capture view and remote video view", log: log_manager_debug, type: .debug)
        linphone_core_set_native_preview_window_id(LC, nil)
        linphone_core_set_native_video_window_id(LC, nil)
        // Set a video view to linphone.
        if captureView != nil && videoView != nil {
            os_log("Set a capture and view remote video", log: log_manager_debug, type: .debug)
            linphone_core_set_native_preview_window_id(LC, SipUAManager.instance().bridgeRetained(obj: captureView!))
            linphone_core_set_native_video_window_id(LC, SipUAManager.instance().bridgeRetained(obj: videoView!))
        } else if captureView != nil && videoView == nil {
            os_log("Set a view remote video to nil", log: log_manager_debug, type: .debug)
            linphone_core_set_native_preview_window_id(LC, SipUAManager.instance().bridgeRetained(obj: captureView!))
            linphone_core_set_native_video_window_id(LC, nil)
        } else if captureView == nil && videoView != nil {
            os_log("Set a capture video to nil", log: log_manager_debug, type: .debug)
            linphone_core_set_native_preview_window_id(LC, nil)
            linphone_core_set_native_video_window_id(LC, SipUAManager.instance().bridgeRetained(obj: videoView!))
        } else {
            os_log("Set a capture and view remote video to nil", log: log_manager_debug, type: .debug)
            linphone_core_set_native_preview_window_id(LC, nil)
            linphone_core_set_native_video_window_id(LC, nil)
        }
    }
    
    /**
     Pause a video camera by disable a camera with call.
     - parameters:
        - call: a specific call to pause a video.
     */
    public func setVideoPause(call: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        os_log("Pause a video", log: log_manager_debug, type: .debug)
        linphone_call_enable_camera(call, UInt8(false.intValue))
    }
    
    /**
     Resume a video camera by enable a camera with call.
     - parameters:
        - call: a specific call to resume a video.
     */
    public func setVideoResume(call: OpaquePointer) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        os_log("Resume a video", log: log_manager_debug, type: .debug)
        linphone_call_enable_camera(call, UInt8(true.intValue))
    }
    
    /**
     Clear all video view.
     */
    public func clearVideoView() {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        os_log("Clear a video", log: log_manager_debug, type: .debug)
        linphone_core_set_native_video_window_id(LC, nil)
        linphone_core_set_native_preview_window_id(LC, nil)
    }
    
    /**
     Check a camera enable status from a current call.
     - returns:
     
        true, If camera in current call is enabled.
     
        false, If camera in current call is disabled.
     */
    public func isCameraEnabled() -> Bool {
        var enable: Bool = false
        // Check current call is not nil.
        if let currentCall = SipUAManager.instance().getCurrentCall() {
            enable = Int(linphone_call_camera_enabled(currentCall)).boolValue
        } else {
            os_log("Current call is nil : Can't check camera", log: log_manager_error, type: .error)
        }
        return enable
    }
    
    /**
     Enable or disable a camera to a current call and bind or unbind a capture view.
     - parameters:
        - enable:
     
            true, To enable a camera to a current call and bind a capture view.
     
            false, To disable a camera to a current call and unbind a capture view.
     
        - captureView: a capture view to preview a camera as an UIView.
     */
    public func enableCamera(enable: Bool, captureView: UIView?) {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return
        }
        // Check current call is not nil.
        if let currentCall = SipUAManager.instance().getCurrentCall() {
            os_log("%@ camera", log: log_manager_debug, type: .debug, enable ? "Open" : "Close")
            if enable {
                if !isCameraEnabled() {
                    os_log("Current call is not open camera yet, Open it", log: log_manager_debug, type: .debug)
                    linphone_call_enable_camera(currentCall, UInt8(true.intValue))
                } else {
                    os_log("Current call is already open camera, Do nothing", log: log_manager_debug, type: .debug)
                }
            } else {
                if isCameraEnabled() {
                    os_log("Current call is opening camera, Close it", log: log_manager_debug, type: .debug)
                    linphone_call_enable_camera(currentCall, UInt8(false.intValue))
                } else {
                    os_log("Current call is not open camera, Do nothing", log: log_manager_debug, type: .debug)
                }
            }
        } else {
            os_log("Current call is nil : Can't enable or disable camera", log: log_manager_error, type: .error)
        }
        // Check temporary capture view is not nil.
        if let view = captureView {
            if enable {
                if linphone_core_get_native_preview_window_id(LC) == nil {
                    os_log("Bind a capture view", log: log_manager_debug, type: .debug)
                    linphone_core_set_native_preview_window_id(LC, SipUAManager.instance().bridgeUnretained(obj: view))
                } else {
                    os_log("Already bind a capture view", log: log_manager_debug, type: .debug)
                }
            } else {
                os_log("Unbind a capture view", log: log_manager_debug, type: .debug)
                linphone_core_set_native_preview_window_id(LC, nil)
            }
        } else {
            os_log("Capture view is nil : Can't bind a capture view", log: log_manager_error, type: .error)
        }
    }
    
    /**
     Get all available camera device.
     - returns: an array of camera device.
     */
    public func getVideoDevice() -> Array<String> {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return []
        }
        // Get all available camera on device.
        let camList = linphone_core_get_video_devices(LC)
        // Create array to collect all camera.
        var camArray: Array<String> = []
        
        if let cams = camList {
            var x = 0
            while cams[x] != nil {
                // Add camera to array.
                camArray.append(String(cString:cams[x]!))
                x += 1
            }
        }
        
        os_log("All video devices : %@", log: log_manager_debug, type: .debug, camArray)
        
        return camArray
    }
    
    /**
     Get all supported video size.
     - returns: an array of SipVideoDefinition.
     */
    public func getSupportedVideoSize() -> Array<SipVideoDefinition> {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return []
        }
        // Get SipUAManager instance.
        let sipManager = SipUAManager.instance()
        // Create array of SipVideoDefinition.
        var allVideoSizes: Array<SipVideoDefinition> = []
        // Get all supported video size.
        let videoSizesList = linphone_factory_get_supported_video_definitions(sipManager.factory)
        // Access to the memory of all supported video size.
        var videoSizes = videoSizesList?.pointee
        
        while videoSizes != nil {
            // Create SipVideoDefinition.
            var sipVd = SipVideoDefinition()
            // Get raw data from memory of all supported video size.
            if let videoSizesData = videoSizes?.data {
                // Add value to SipVideoDefinition.
                let videoSizesDataPt = OpaquePointer(videoSizesData)
                sipVd.name = String(cString: linphone_video_definition_get_name(videoSizesDataPt))
                sipVd.height = Int(linphone_video_definition_get_height(videoSizesDataPt))
                sipVd.width = Int(linphone_video_definition_get_width(videoSizesDataPt))
                // Add SipVideoDefinition to array.
                allVideoSizes.append(sipVd)
            }
            // If the next memory of all supported video size is exist, Move to next codec.
            if (videoSizes?.next) != nil {
                videoSizes = videoSizes?.next.pointee
            } else {
                break
            }
        }
        
        os_log("All supported video size : %@", log: log_manager_debug, type: .debug, allVideoSizes)
        
        return allVideoSizes
    }
    
    /**
     Check video auto accept policy.
     - returns:
     
        true, If allow to accept video auto.
     
        false, If not allow to accept video auto.
     */
    public func getVideoAutoAccept() -> Bool {
        let videoPolicy = linphone_core_get_video_activation_policy(LC)
        let videoAutoAccept = linphone_video_activation_policy_get_automatically_accept(videoPolicy)
        let videoAutoInitiate = linphone_video_activation_policy_get_automatically_initiate(videoPolicy)
        os_log("Video policy auto initiate : %@", log: log_manager_debug, type: .debug, Int(videoAutoInitiate).boolValue ? "true" : "false")
        os_log("Video policy auto accept : %@", log: log_manager_debug, type: .debug, Int(videoAutoAccept).boolValue ? "true" : "false")
        return Int(videoAutoAccept).boolValue
    }
    
    /**
     Set video auto accept policy.
     - parameters:
        - enable:
     
            true, To enable video auto accept.
     
            false, To disable video auto accept.
     */
    public func setVideoAutoAccept(enable: Bool) {
        let videoPolicy = linphone_core_get_video_activation_policy(LC)
        linphone_video_activation_policy_set_automatically_accept(videoPolicy, UInt8(enable.intValue))
        linphone_core_set_video_activation_policy(LC, videoPolicy)
    }
    
    /**
     Check a local call with video or audio.
     - parameters:
        - call: a specific call to check local video.
     - returns:
     
        true, If a local call enable video.
     
        false, If a local call doesn't enable video.
     */
    public func isVideoEnabled(call: OpaquePointer) -> Bool {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        // Check call state is not release.
        if linphone_call_get_state(call) != LinphoneCallStateReleased {
            // Get current param and check for video enabled.
            let callParam = linphone_call_get_current_params(call)
            return Int(linphone_call_params_video_enabled(callParam)).boolValue
        }
        return false
        
    }
    
    /**
     Check a remote call with video or audio.
     - parameters:
        - call: a specific call to check remote video.
     - returns:
     
        true, If a remote call enable video.
     
        false, If a remote call doesn't enable video.
     */
    public func isRemoteVideoEnabled(call: OpaquePointer) -> Bool {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return false
        }
        // Check call state is not release.
        if linphone_call_get_state(call) != LinphoneCallStateReleased {
            // Get remote param and check for video enabled.
            let callRomoteParam = linphone_call_get_remote_params(call)
            return Int(linphone_call_params_video_enabled(callRomoteParam)).boolValue
        }
        return false
    }
    
}
