//
//  SipUAChatManager.swift
//  SipUAFramwork
//
//  Created by Sarunyu Prasert on 7/3/2561 BE.
//  Copyright © 2561 Entronica. All rights reserved.
//

import LinphoneModule

// MARK: - Global instance
/**
 Get SipUAChatManager instance (a compute property).
 */
internal var SipChatManager: SipUAChatManager {
    if SipUAChatManager.sipUAChatManagerInstance == nil {
        SipUAChatManager.sipUAChatManagerInstance = SipUAChatManager()
    }
    return SipUAChatManager.sipUAChatManagerInstance!
}

// MARK: - Enumeration Message status
/**
 A custom enumerations of message status.
 - parameters:
    - Idle: an idle status.
    - Delivered: a delivered status.
    - Displayed: a displayed status.
    - In_progress: an in progress status.
    - Not_delivered: a not delivered status.
    - Delivered_to_user: a delivered to user status.
    - File_transfer_done: a file transfer done status.
    - File_transfer_error: a file transfer error status.
 */
public enum MessageStatusList: String {
    case Idle = "Idle"
    case Delivered = "Delivered"
    case Displayed = "Displayed"
    case In_progress = "In progress"
    case Not_delivered = "Not delivered"
    case Delivered_to_user = "Delivered to user"
    case File_transfer_done = "File transfer done"
    case File_transfer_error = "File transfer error"
}

// MARK: - Main class
/**
 SipUAChatManager is a class that contain all function about chat.
 */
internal class SipUAChatManager {
    
    // MARK: - Properties
    // Singleton (The static instance).
    fileprivate static var sipUAChatManagerInstance: SipUAChatManager?
    
    // MARK: - Chat message function
    /**
     Get a specific call id from message.
     - parameters:
        - message: a specific message to get id.
     - returns: a call id as string.
     */
    public func getMessageCallID(message: OpaquePointer?) -> String {
        guard message != nil else {
            os_log("Message is nil", log: log_manager_error, type: .error)
            return ""
        }
        // Get call id from message.
        if let callID = linphone_chat_message_get_message_id(message) {
            return String(cString: callID)
        } else {
            os_log("Message call id is nil", log: log_manager_error, type: .error)
        }
        return ""
    }
    
    /**
     Get message from call id.
     - parameters:
        - callID: a call id to get message.
     - returns: a message.
     */
    public func getMessageFromCallID(callID: String?) -> OpaquePointer? {
        guard let callID = callID else {
            os_log("Call id is nil", log: log_manager_error, type: .error)
            return nil
        }
        // Check all chat room
        let allChatRooms = getAllChatRoom()
        if allChatRooms.count != 0 {
            for chatRoom in allChatRooms {
                // Check all message in chat room that message call id is match with input call id
                let allMessages = getChatRoomAllMsg(chatRoom: chatRoom)
                if allMessages.count != 0 {
                    for message in allMessages {
                        let callIDTmp = getMessageCallID(message: message)
                        os_log("Message call id : %@", log: log_manager_debug, type: .debug, callIDTmp)
                        if (callIDTmp != "") && (callIDTmp == callID) {
                            os_log("Match call id, Return message", log: log_manager_debug, type: .debug)
                            return message
                        }
                    }
                } else {
                    os_log("No messages in chat room", log: log_manager_error, type: .error)
                }
            }
        } else {
            os_log("Not found chat rooms", log: log_manager_error, type: .error)
        }
        return nil
    }
    
    /**
     Get a remote address of message.
     - parameters:
        - message: a linphone message to get remote address.
     - returns: a linphone remote address.
     */
    public func getMessageRemoteAddress(message: OpaquePointer) -> OpaquePointer {
        // Return remote address from message.
        return linphone_chat_message_get_from_address(message)
    }
    
    /**
     Get a local address of message.
     - parameters:
        - message: a linphone message to get local address.
     - returns: a linphone local address.
     */
    public func getMessageLocalAddress(message: OpaquePointer) -> OpaquePointer {
        // Return local address from message.
        return linphone_chat_message_get_to_address(message)
    }
    
    /**
     Get a date of message.
     - parameters:
        - message: a message to get time.
     - returns: a message date as time interval type.
     */
    public func getMessageDate(message: OpaquePointer) -> TimeInterval {
        return TimeInterval(linphone_chat_message_get_time(message))
    }
    
    /**
     Get a text of message.
     - parameters:
        - message: a message to get text.
     - returns: a message text as string.
     */
    public func getMessageText(message: OpaquePointer?) -> String {
        if let messagePt = message {
            if linphone_chat_message_get_text(messagePt) != nil {
                return String(cString: linphone_chat_message_get_text_content(messagePt))
            } else {
                os_log("Can't get message text : message is not text", log: log_manager_error, type: .error)
                return ""
            }
        } else {
            os_log("Can't get message text : message is nil", log: log_manager_error, type: .error)
            return ""
        }
    }
    
    /**
     Find message from chatroom. Chat room can set to nil, It will get chat room from message itself.
     - parameters:
        - chatRoom: a chat room to find message.
        - message: a message to find in chat room.
     - returns: a message.
     */
    public func findMessage(chatRoom: OpaquePointer?, message: OpaquePointer) -> OpaquePointer? {
        var chatRooFrommMsg: OpaquePointer
        var tmpMessage: OpaquePointer?
        if chatRoom == nil {
            chatRooFrommMsg = linphone_chat_message_get_chat_room(message)
        } else {
            chatRooFrommMsg = chatRoom!
        }
        let msgCallId = linphone_chat_message_get_message_id(message)
        os_log("Message call id : %@", log: log_manager_debug, type: .debug, String(cString: msgCallId!))
        tmpMessage = linphone_chat_room_find_message(chatRooFrommMsg, msgCallId)
        return tmpMessage
    }
    
    /**
     Check a message is from local or remote.
     - parameters:
        - message: a message to get status.
     - returns:
     
        true, If message has been sent.
     
        false, If message has been received.
     */
    public func isOutgoingMessage(message: OpaquePointer) -> Bool {
        return Int(linphone_chat_message_is_outgoing(message)).boolValue
    }
    
    /**
     Check message status is read or not.
     - parameters:
        - message: a message to get status.
     - returns:
     
        true, If message is read.
     
        false, If message is not read.
     */
    public func isMessageRead(message: OpaquePointer) -> Bool {
        return Int(linphone_chat_message_is_read(message)).boolValue
    }
    
    /**
     Check a message is text or not.
     - parameters:
        - message: a message to check text.
     - returns:
     
        true, If message is text.
     
        false, If message is not text.
     */
    public func isMessageText(message: OpaquePointer) -> Bool {
        return Int(linphone_chat_message_is_text(message)).boolValue
    }
    
    /**
     Delete a message in chat room.
     - parameters:
        - chatRoom: a chat room that has a message in history. Can set to nil it will get chat room from message.
        - message: a message to delete.
     */
    public func deleteMessage(chatRoom: OpaquePointer?, message: OpaquePointer) {
        
        if chatRoom == nil {
            let room = linphone_chat_message_get_chat_room(message)
            linphone_chat_room_delete_message(room, message)
        } else {
            linphone_chat_room_delete_message(chatRoom, message)
        }
    }
    
    /**
     Create a message.
     - parameters:
        - chatRoom: a chat room to create message.
        - message: a message as string.
     - returns: a message.
     */
    public func createMessage(chatRoom: OpaquePointer, message: String) -> OpaquePointer {
        return linphone_chat_room_create_message(chatRoom, message.stringToUnsafePointerInt8())
    }
    
    /**
     Send a message.
     - parameters:
        - message: a message to send.
     */
    public func sendMessage(message: OpaquePointer) {
        linphone_chat_message_send(message)
    }
    
    /**
     Get a message status.
     - parameters:
        - message: a message to get status.
     - returns: a message status as string.
     */
    public func getMessageStatus(message: OpaquePointer) -> String {
        return SipUtils.messageStateToString(messageState: linphone_chat_message_get_state(message))
    }
    
    /**
     Setup message state callback for message state change.
     - parameters:
        - message: a message to set callback for message state change.
     */
    public func setupCbForMessageStateChange(message: OpaquePointer) {
        // Set user data callback to linphone message back. We will using it in closure.
        linphone_chat_message_set_user_data(message, SipUAManager.instance().bridgeRetained(obj: SipUAManager.instance()))
        // Get callback from message.
        let msgCb = linphone_chat_message_get_callbacks(message)
        // Set message state change callback.
        linphone_chat_message_cbs_set_msg_state_changed(msgCb, SipUAManager.instance().LinphoneMessageStateChangeCb)
    }
    
    /**
     Remove message state callback for message state change.
     - parameters:
        - message: a message to remove callback for message state change.
     */
    public func removeCbForMessageStateChange(message: OpaquePointer) {
        // Set user data callback to linphone message back. We will using it in closure.
        linphone_chat_message_set_user_data(message, nil)
        // Get callback from message.
        let msgCb = linphone_chat_message_get_callbacks(message)
        // Set message state change callback.
        linphone_chat_message_cbs_set_msg_state_changed(msgCb, nil)
    }
    
    // MARK: - Chat room function
    /**
     Get all chat rooms.
     - returns: an array of sorted chat room from newest to oldest.
     */
    public func getAllChatRoom() -> Array<OpaquePointer?> {
        
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return []
        }
        
        // Create array to collect all chat room details.
        var chatRoomArray: Array<OpaquePointer?> = []
        // Get all chat rooms.
        let roomsList = linphone_core_get_chat_rooms(LC)
        // Access to the memory of all chat rooms.
        var rooms = roomsList?.pointee
        
        while rooms != nil {
            // Get raw data from memory of all rooms.
            if let roomData = rooms?.data {
                // Cast to pointer.
                let roomDataPt = OpaquePointer(roomData)
                // Get 1 mmesage from chat room history.
                let messageInHistory = linphone_chat_room_get_history(roomDataPt, 1)
                // Declare property to keep last message.
                var lastMsg: OpaquePointer?
                // If there is a history.
                if messageInHistory?.pointee != nil {
                    // Cast to pointer.
                    let messageInHistoryPt = OpaquePointer(messageInHistory?.pointee.data)
                    // Get last message.
                    lastMsg = linphone_chat_message_ref(messageInHistoryPt)
                    bctbx_list_free(messageInHistory)
                }
                // Set user data of chat room by adding a last message.
                linphone_chat_room_set_user_data(roomDataPt, UnsafeMutableRawPointer(lastMsg))
                // Add chat room to array.
                chatRoomArray.append(roomDataPt)
            }
            // If the next memory of all chat rooms is exist, Move to next chat room.
            if rooms?.next != nil {
                rooms = rooms?.next.pointee
            } else {
                break
            }
        }
        
        // Sort chat room from newest to oldest.
        chatRoomArray = chatRoomArray.sorted(by: {
            // Get user data that is last message from each chat room.
            let last_first_message = linphone_chat_room_get_user_data($0)
            let last_second_message = linphone_chat_room_get_user_data($1)
            if last_first_message != nil && last_second_message != nil {
                // Get message time.
                // Which obj has more time means that obj is the latest obj.
                let time_first = linphone_chat_message_get_time(OpaquePointer(last_first_message))
                let time_second = linphone_chat_message_get_time(OpaquePointer(last_second_message))
                // If obj1 time less than obj2 time then obj1 should not add before obj2.
                if time_first < time_second {
                    return false
                // If obj1 time more than obj2 time then obj1 should add before obj2.
                } else if time_first > time_second {
                    return true
                // If obj1 time (more than & equal) or (less than & equal) or (equal) obj2 time then obj1 should add before obj2.
                } else {
                    return true
                }
            }
            // For default. Should add that obj first.
            return true
        })
        
        return chatRoomArray
    }
    
    /**
     Delete a chat room.
     - parameters:
        - chatRoom: a chat room to delete.
     */
    public func deleteChatRoom(chatRoom: OpaquePointer) {
        linphone_core_delete_chat_room(LC, chatRoom)
    }
    
    /**
     Mark all message in chat room read.
     - parameters:
        - chatRoom: a chat room to mark.
     */
    public func markAsRead(chatRoom: OpaquePointer) {
        linphone_chat_room_mark_as_read(chatRoom)
    }
    
    /**
     Notified remote that local is composing.
     - parameters:
        - chatRoom: a chat room to notified compose.
     */
    public func composeMessage(chatRoom: OpaquePointer) {
        linphone_chat_room_compose(chatRoom)
    }
    
    /**
     Create chat room with username if chat room doesn't exist.
     - parameters:
        - username: an username as string, Example - If full address is sip:John@testserver.com:5060 then [username] parameter should be John.
     - returns: a chat room.
     */
    public func createChatRoom(username: String) -> OpaquePointer {
        
        // Get default proxy config.
        let prxCfg = linphone_core_get_default_proxy_config(LC)
        // Get domain from defualt proxy config.
        let domainCfg = linphone_proxy_config_get_domain(prxCfg)
        os_log("Domain name from default proxy config : %@", log: log_manager_debug, type: .debug, String(cString: domainCfg!))
        // Create a address string.
        let addressStr = String(format: "sip:%@@%@", username, String(cString: domainCfg!))
        os_log("Address to create chat room : %@", log: log_manager_debug, type: .debug, addressStr)
        // Create a linphone address.
        let laddress = linphone_core_interpret_url(LC, addressStr.stringToUnsafePointerInt8())
        // Convert linphone address to string.
        let uri = linphone_address_as_string(laddress)
        os_log("Create/Get chat room to send message to : %@", log: log_manager_debug, type: .debug, String(cString: uri!))
        return linphone_core_get_chat_room(LC, laddress)
    }
    
    /**
     Find chat room from local and peer address.
     - parameters:
        - localAddr: a local address as string.
        - peerAddr: a peer address as string.
     - returns: a chat room.
     */
    public func findChatRoom(localAddr: String?, peerAddr: String?) -> OpaquePointer? {
        guard LC != nil else {
            os_log("Linphonecore is nil", log: log_manager_error, type: .error)
            return nil
        }
        // Find chat room from local and peer address.
        if let localAddress = localAddr, let peerAddress = peerAddr {
            if let local = linphone_address_new(localAddress.stringToUnsafePointerInt8()),
                let peer = linphone_address_new(peerAddress.stringToUnsafePointerInt8()) {
                os_log("Local address : %@", log: log_manager_debug, type: .debug, SipUtils.getUsernameFromAddress(address: local) ?? "nil")
                os_log("Peer address : %@", log: log_manager_debug, type: .debug, SipUtils.getUsernameFromAddress(address: peer) ?? "nil")
                if let chatRoom = linphone_core_find_chat_room(LC, peer, local) {
                    os_log("Found chat room with : %@", log: log_manager_debug, type: .debug, SipUtils.getUsernameFromAddress(address: getChatRoomRemoteAddress(chatRoom: chatRoom)) ?? "nil")
                    linphone_address_unref(local)
                    linphone_address_unref(peer)
                    return chatRoom
                } else {
                    os_log("Not found chat room", log: log_manager_error, type: .error)
                }
            } else {
                os_log("Create address from string error", log: log_manager_error, type: .error)
            }
        } else {
            os_log("Local address or peer address string is nil", log: log_manager_debug, type: .debug)
        }
        return nil
    }
    
    /**
     Get a remote address of chat room.
     - parameters:
        - chatRoom: a chat room to get remote address.
     - returns: a remote address.
     */
    public func getChatRoomRemoteAddress(chatRoom: OpaquePointer) -> OpaquePointer {
        return linphone_chat_room_get_peer_address(chatRoom)
    }
    
    /**
     Get a local address of chat room.
     - parameters:
        - chatRoom: a chat room to get local address.
     - returns: a local address.
     */
    public func getChatRoomLocalAddress(chatRoom: OpaquePointer) -> OpaquePointer {
        return linphone_chat_room_get_local_address(chatRoom)
    }
    
    /**
     Get unread message count of chat room.
     - parameters:
        - chatRoom: a chat room to get unread message count.
     - returns: an unread message count as int.
     */
    public func getChatRoomUnreadMsgCount(chatRoom: OpaquePointer) -> Int {
        return Int(linphone_chat_room_get_unread_messages_count(chatRoom))
    }
    
    /**
     Get unread message count of all chat room.
     - returns: an unread message count as int.
     */
    public func getAllChatRoomUnreadMsgCount() -> Int {
        var count = 0
        for room in getAllChatRoom() {
           count += Int(linphone_chat_room_get_unread_messages_count(room))
        }
        return count
    }
    
    /**
     Check a chat room is composing or not.
     - parameters:
        - chatRoom: a chat room to get status.
     - returns:
     
        true, If remote chat room is typing.
     
        false, If remote chat room is not typing.
     */
    public func isChatRoomRemoteComposing(chatRoom: OpaquePointer) -> Bool {
        return Int(linphone_chat_room_is_remote_composing(chatRoom)).boolValue
    }
    
    /**
     Get a last message of chat room.
     - parameters:
        - chatRoom: a chat room to get message.
     - returns: a last message.
     */
    public func getChatRoomLastMsg(chatRoom: OpaquePointer) -> OpaquePointer? {
        
        // Declare a properties to keep result.
        var lastMsg: OpaquePointer?
        // Get latest chat message.(There is only one message)
        let msgHistoryList = linphone_chat_room_get_history(chatRoom, 1)
        // Access to memory of chat message.
        var msgHistorys = msgHistoryList?.pointee
        
        while msgHistorys != nil {
            // Get chat message data.
            let msgHistoryData = OpaquePointer(msgHistorys?.data)
            lastMsg = msgHistoryData
            // If the next memory of chat message is exist, Move to next chat message.
            if msgHistorys?.next != nil {
                msgHistorys = msgHistorys?.next.pointee
            } else {
                break
            }
        }
        
        return lastMsg
    }
    
    /**
     Get a chat room from message.
     - parameters:
        - message: a message to get chat room.
     - returns: a chat room.
     */
    public func getChatRoomFromMsg(message: OpaquePointer) -> OpaquePointer {
        return linphone_chat_message_get_chat_room(message)
    }
    
    /**
     Get all chat message history in chat room.
     - parameters:
        - chatRoom: a chat room to get history chat message.
     - returns: an array of all message in chat room.
     */
    public func getChatRoomAllMsg(chatRoom: OpaquePointer?) -> Array<OpaquePointer?> {
        
        guard LC != nil && chatRoom != nil else {
            os_log("Linphonecore is nil or chat room is nil", log: log_manager_error, type: .error)
            return []
        }
        
        // Create array to collect all chat messages.
        var messageArray: Array<OpaquePointer?> = []
        // Get all chat messages.
        let msgList = linphone_chat_room_get_history(chatRoom, 0)
        // Access to the memory of all chat messages.
        var chats = msgList?.pointee
        
        while chats != nil {
            // Get raw data from memory of all chats.
            if let chatData = chats?.data {
                // Cast to pointer.
                let chatDataPt = OpaquePointer(chatData)
                // Add chat message to array.
                messageArray.append(chatDataPt)
            }
            // If the next memory of all chat messages is exist, Move to next chat message.
            if chats?.next != nil {
                chats = chats?.next.pointee
            } else {
                break
            }
        }
        
        return messageArray
    }
    
    /**
     Get a last message date of chat room.
     - parameters:
        - chatRoom: a chat room to get last message date.
        - dateFormat: a date format to get. Can set to nil it will use default format (HH:mm) for the same day, (dd/MM - HH:mm) for the past day.
     - returns: a last message date as string.
     */
    public func getChatRoomLastMsgDate(chatRoom: OpaquePointer, dateFormat: String?) -> String {
        
        // Declare a properties to keep result.
        var lastMsgDate: String = ""
        // Get latest chat message.(There is only one message)
        let msgHistoryList = linphone_chat_room_get_history(chatRoom, 1)
        // Access to memory of chat message.
        var msgHistorys = msgHistoryList?.pointee
        
        while msgHistorys != nil {
            // Get chat message data.
            let msgHistoryData = OpaquePointer(msgHistorys?.data)
            // Get time from chat message.
            if dateFormat != nil {
                lastMsgDate = SipUtils.timeToString(time: TimeInterval(linphone_chat_message_get_time(msgHistoryData)), dateFormat: dateFormat)
            } else {
                lastMsgDate = SipUtils.timeToString(time: TimeInterval(linphone_chat_message_get_time(msgHistoryData)), dateFormat: nil)
            }
            // If the next memory of chat message is exist, Move to next chat message.
            if msgHistorys?.next != nil {
                msgHistorys = msgHistorys?.next.pointee
            } else {
                break
            }
        }
        
        return lastMsgDate
    }
    
    
    
    
}





