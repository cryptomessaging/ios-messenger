import Chatto

struct MessageStatusName {
    static let SENDING = "sending"
    static let FAILED = "failed"
    static let SUCCESS = "success"
}

class MessageHelper {
    
    static let DEBUG = false
    
    class func asString(_ status:MessageStatus) -> String {
        switch status {
        case .sending:
            return MessageStatusName.SENDING
        case .failed:
            return MessageStatusName.FAILED
        case .success:
            return MessageStatusName.SUCCESS
        }
    }
    
    class func asStatus(_ status:String?) -> MessageStatus? {
        if let s = status {
            switch s {
            case  MessageStatusName.SENDING:
                return MessageStatus.sending
            case MessageStatusName.FAILED:
                return MessageStatus.failed
            case MessageStatusName.SUCCESS:
                return MessageStatus.success
            default:
                DebugLogger.instance.append( function:"asStatus()", message:"Unknown status of \(String(describing: status))" )
                return nil
            }
        } else {
            return nil
        }
    }

    
    // rowid is database row id and unique on this device
    class func createTextMessage( _ rowid:String, tid:String, cid:String, isMine:Bool, sameSenderAsLastMessage: Bool, created:String, text:String, status:String? ) -> TextMessage {
        
        let src = ChatMessage(tid:tid,from:cid,created:created,body:text,media:nil)
        
        let date = TimeHelper.asDate(created)!
        let st = MessageHelper.asStatus( status )
        let msg = TextMessage(uid:rowid, msg:src, isIncoming:!isMine, date:date, status:st!, text:text, sameSenderAsLastMessage:sameSenderAsLastMessage )
        if DEBUG {
            print( "Created \(msg)" )
        }
        return msg
    }
    
    class func createPhotoMessage(_ rowid:String, tid:String, cid:String, isMine:Bool, sameSenderAsLastMessage: Bool, created:String, media:[Media], status:String? ) -> PhotoMessage {
        
        let src = ChatMessage(tid:tid,from:cid,created:created,body:nil,media:media)
        
        let date = TimeHelper.asDate(created)!
        let st = MessageHelper.asStatus( status )
        let msg = PhotoMessage(uid:rowid, msg:src, isIncoming:!isMine, date:date, status:st!, sameSenderAsLastMessage:sameSenderAsLastMessage )
        if DEBUG {
            print( "Created \(msg)" )
        }
        return msg
    }
}
