//
//  SipUAPreferences.swift
//  SipUAFramwork
//
//  Created by Sarunyu Prasert on 25/1/2561 BE.
//  Copyright © 2561 Entronica. All rights reserved.
//

import UIKit
import LinphoneModule

// MARK: - Global instance
/**
 Get SipUAPreferences instance (a compute property).
 */
internal var SipPreferences: SipUAPreferences {
    if SipUAPreferences.sipUAPreferencesInstance == nil {
        SipUAPreferences.sipUAPreferencesInstance = SipUAPreferences()
    }
    return SipUAPreferences.sipUAPreferencesInstance!
}

// MARK: - Main class
/**
 SipUAPreferences is a class that contain all function about setting.
 */
internal class SipUAPreferences {
    
    // MARK: - Properties
    // Singleton (The static instance).
    fileprivate static var sipUAPreferencesInstance: SipUAPreferences?
    
    // MARK: - Get/Set functions
    /**
     Get the video frame rate, Previously set by setPreferredFramerate().
     - returns: a frame rate.
     */
    public func getPreferredFramerate() -> Float {
        return linphone_core_get_preferred_framerate(LC)
    }
    
    /**
     Set the video frame rate, Based on the available bandwidth constraints and network conditions.
     There is no warranty that the frame rate be the actual frame rate.
     - parameters:
        - fps: frame rate per second as int.
     */
    public func setPreferredFramerate(fps: Float) {
        linphone_core_set_preferred_framerate(LC, fps)
    }
    
    /**
     Get the video definition for the stream that is captured and sent to the remote.
     - returns: a SipVideoDefinition.
     */
    public func getPreferredVideoSize() -> SipVideoDefinition {
        
        // Get video definition.
        let videoDef = linphone_core_get_preferred_video_definition(LC)
        
        // Create SipVideoDefinition and set data.
        var sipVideoDef = SipVideoDefinition()
        sipVideoDef.name = String(cString :linphone_video_definition_get_name(videoDef))
        sipVideoDef.height = Int(linphone_video_definition_get_height(videoDef))
        sipVideoDef.width = Int(linphone_video_definition_get_width(videoDef))
        
        return sipVideoDef
        
    }
    
    /**
     Set the video size by name.
     - parameters:
        - size: a video size as string, Use getSupportedVideoSize() to see all video size name.
     */
    public func setPreferredVideoSize(size: String) {
        linphone_core_set_preferred_video_size_by_name(LC, size.stringToUnsafePointerInt8())
    }
    
    /**
     Set incoming call timeout.
     - parameters:
        - seconds: a timing as int.
     */
    public func setIncomingTimeout(seconds: Int) {
        linphone_core_set_inc_timeout(LC, Int32(seconds))
    }
    
    /**
     Get incoming call timeout.
     - returns: an incoming call timeout as int.
     */
    public func getIncomingTimeout() -> Int {
        return Int(linphone_core_get_inc_timeout(LC))
    }
    
    /**
     Get all audio codecs.
     - returns: an array of SipPayloadType.
     */
    public func getAudioCodecs() -> Array<SipPayloadType> {
        return SipAudioManager.getAudioCodecs()
    }
    
    /**
     Get all video codecs.
     - returns: an array of SipPayloadType.
     */
    public func getVideoCodecs() -> Array<SipPayloadType> {
        return SipVideoManager.getVideoCodecs()
    }
    
    /**
     Check a specific payload type is enabled or disabled.
     - returns:
     
        true, If a payload type is enabled.
     
        false, If a payload type is disabled.
     */
    public func isPayloadTypeEnabled(pt: SipPayloadType) -> Bool {
        
        // SipPayloadType name.
        let ptName = pt.name
        
        // Status.
        var enable = false
        
        // Get all video codecs.
        let videoCodecsList = linphone_core_get_video_payload_types(LC)
        // Access to the memory of video codecs.
        var videoCodecs = videoCodecsList?.pointee
        // Loop for all video codec.
        while videoCodecs != nil {
            // Get raw data from memory of video codecs.
            let videoCodecsData = videoCodecs?.data
            // Get video payload type name.
            let videoPt = OpaquePointer(videoCodecsData)
            let videoPtName = String(cString: linphone_payload_type_get_mime_type(videoPt))
            // If found payload type name, Check it is enabled or not.
            if ptName == videoPtName {
                enable = Int(linphone_payload_type_enabled(videoPt)).boolValue
                break
            }
            // If the next memory of video codec is exist, Move to next codec.
            if (videoCodecs?.next) != nil {
                videoCodecs = videoCodecs?.next.pointee
            } else {
                break
            }
        }
        
        // Get all audio codecs.
        let audioCodecsList = linphone_core_get_audio_payload_types(LC)
        // Access to the memory of audio codecs.
        var audioCodecs = audioCodecsList?.pointee
        // Loop for all audio codec.
        while audioCodecs != nil {
            // Get raw data from memory of audio codecs.
            let audioCodecsData = audioCodecs?.data
            // Get audio payload type name.
            let audioPt = OpaquePointer(audioCodecsData)
            let audioPtName = String(cString: linphone_payload_type_get_mime_type(audioPt))
            // If found payload type name, Check it is enabled or not.
            if ptName == audioPtName {
                enable = Int(linphone_payload_type_enabled(audioPt)).boolValue
                break
            }
            // If the next memory of audio codec is exist, Move to next codec.
            if (audioCodecs?.next) != nil {
                audioCodecs = audioCodecs?.next.pointee
            } else {
                break
            }
        }
        
        return enable
        
    }
    
    /**
     Set maximum available upload bandwidth, This is IP bandwidth in kbit/s.
     - parameters:
        - uploadBW: the bandwidth in kbits/s, 0 for infinite.
     */
    public func setUploadBandwidth(uploadBW: Int) {
        linphone_core_set_upload_bandwidth(LC, Int32(uploadBW))
    }
    
    /**
     Get maximum available upload bandwidth.
     - returns: an upload bandwidth as int.
     */
    public func getUploadBandwidth() -> Int {
        return Int(linphone_core_get_upload_bandwidth(LC))
    }
    
    /**
     Set maximum available download bandwidth, This is IP bandwidth in kbit/s.
     - parameters:
        - downloadBW: the bandwidth in kbits/s, 0 for infinite.
     */
    public func setDownloadBandwidth(downloadBW: Int) {
        linphone_core_set_download_bandwidth(LC, Int32(downloadBW))
    }
    
    /**
     Get maximum available download bandwidth.
     - returns: an download bandwidth as int.
     */
    public func getDownloadBandwidth() -> Int {
        return Int(linphone_core_get_download_bandwidth(LC))
    }
    
    /**
     Enable or disable a specific payload type.
     - parameters:
        - pt: a specific payload type as SipPayloadType.
        - enable:
     
            true, To enable a payload type.
     
            false, To disable a payload type.
     */
    public func enablePayloadType(pt: SipPayloadType, enable: Bool) {
        
        // SipPayloadType name.
        let ptName = pt.name
        
        // Get all video codecs.
        let videoCodecsList = linphone_core_get_video_payload_types(LC)
        // Access to the memory of video codecs.
        var videoCodecs = videoCodecsList?.pointee
        // Loop for all video codec.
        while videoCodecs != nil {
            // Get raw data from memory of video codecs.
            let videoCodecsData = videoCodecs?.data
            // Get video payload type name.
            let videoPt = OpaquePointer(videoCodecsData)
            let videoPtName = String(cString: linphone_payload_type_get_mime_type(videoPt))
            // If found payload type name, Check it is enabled or not.
            if ptName == videoPtName {
                linphone_payload_type_enable(videoPt, UInt8(enable.intValue))
                break
            }
            // If the next memory of video codec is exist, Move to next codec.
            if (videoCodecs?.next) != nil {
                videoCodecs = videoCodecs?.next.pointee
            } else {
                break
            }
        }
        
        // Get all audio codecs.
        let audioCodecsList = linphone_core_get_audio_payload_types(LC)
        // Access to the memory of audio codecs.
        var audioCodecs = audioCodecsList?.pointee
        // Loop for all audio codec.
        while audioCodecs != nil {
            // Get raw data from memory of audio codecs.
            let audioCodecsData = audioCodecs?.data
            // Get audio payload type name.
            let audioPt = OpaquePointer(audioCodecsData)
            let audioPtName = String(cString: linphone_payload_type_get_mime_type(audioPt))
            // If found payload type name, Check it is enabled or not.
            if ptName == audioPtName {
                linphone_payload_type_enable(audioPt, UInt8(enable.intValue))
                break
            }
            // If the next memory of audio codec is exist, Move to next codec.
            if (audioCodecs?.next) != nil {
                audioCodecs = audioCodecs?.next.pointee
            } else {
                break
            }
        }
        
    }
    
    
    
    
    
}
