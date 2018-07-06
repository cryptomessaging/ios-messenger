import Foundation
import Chatto

open class TextMessage : ChatItem, CustomStringConvertible {
    
    public struct Constant {
        static let ItemType:ChatItemType  = "motext"
    }
    
    init(uid:String, msg:ChatMessage, isIncoming:Bool, date:Date, status:MessageStatus, text:String, sameSenderAsLastMessage:Bool ) {
        super.init(uid: uid, msg:msg, isIncoming: isIncoming, date: date, status: status, sameSenderAsLastMessage:sameSenderAsLastMessage )
    }
    
    override open var type: ChatItemType {
        return Constant.ItemType
    }
    
    public var description: String {
        return "TextMessage of \(msg.toJSONString())"
    }
}
