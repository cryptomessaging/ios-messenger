import Foundation
import Chatto

open class PhotoMessage : ChatItem, CustomStringConvertible {
    
    public struct Constant {
        static let ItemType:ChatItemType  = "mophoto"
    }
    
    override init(uid:String, msg:ChatMessage, isIncoming:Bool, date:Date, status:MessageStatus, sameSenderAsLastMessage:Bool ) {
        super.init(uid: uid, msg:msg, isIncoming: isIncoming, date: date, status: status, sameSenderAsLastMessage:sameSenderAsLastMessage )
    }
    
    override open var type: ChatItemType {
        return Constant.ItemType
    }
    
    public var description: String {
        return "PhotoMessage of \(String(describing: msg.toJSONString()))"
    }
}
