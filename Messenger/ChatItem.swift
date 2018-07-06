import Foundation
import Chatto

public enum MessageStatus {
    case failed
    case sending
    case success
}

public struct ChatItemDecorationAttributes: ChatItemDecorationAttributesProtocol {
    public let bottomMargin: CGFloat
    public let showsTail: Bool
    public init(bottomMargin: CGFloat, showsTail: Bool) {
        self.bottomMargin = bottomMargin
        self.showsTail = showsTail
    }
}

open class ChatItem : ChatItemProtocol {
    
    open var uid: String  // unique id for message, can be locally generated i.e. db row id; NOT a user id!
    var msg:ChatMessage
    open var isIncoming: Bool
    open var date: Date
    open var status: MessageStatus

    open var sameSenderAsLastMessage: Bool // helps with when to place chat heads
    
    init(uid:String, msg:ChatMessage, isIncoming:Bool, date:Date, status:MessageStatus, sameSenderAsLastMessage:Bool ) {
        self.uid = uid
        self.msg = msg
        self.isIncoming = isIncoming
        self.date = date
        self.status = status
        self.sameSenderAsLastMessage = sameSenderAsLastMessage
    }
    
    open var type: ChatItemType {
        return "base" as ChatItemType
    }
    
    open func statusKey() -> String {
        return ChatItem.statusKey(status)
    }
    
    open class func statusKey(_ status:MessageStatus) -> String {
        switch status {
        case .success:
            return "ok"
        case .sending:
            return "sending"
        case .failed:
            return "failed"
        }
    }
}
