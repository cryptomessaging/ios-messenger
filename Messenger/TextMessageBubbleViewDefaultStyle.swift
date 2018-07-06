import Foundation
import Chatto

open class TextMessageBubbleViewDefaultStyle: TextMessageBubbleViewStyleProtocol {
    
    public init () {}
    
    lazy var baseStyle = BaseMessageCollectionViewCellDefaultSyle()
    lazy var images: [String: UIImage] = {
        return [
            "incoming_tail" : UIImage(named: "bubble-incoming-tail", in: Bundle(for: TextMessageBubbleViewDefaultStyle.self), compatibleWith: nil)!,
            "incoming_notail" : UIImage(named: "bubble-incoming", in: Bundle(for: TextMessageBubbleViewDefaultStyle.self), compatibleWith: nil)!,
            "outgoing_tail" : UIImage(named: "bubble-outgoing-tail", in: Bundle(for: TextMessageBubbleViewDefaultStyle.self), compatibleWith: nil)!,
            "outgoing_notail" : UIImage(named: "bubble-outgoing", in: Bundle(for: TextMessageBubbleViewDefaultStyle.self), compatibleWith: nil)!,
        ]
    }()
    
    lazy var font = {
        return UIFont.systemFont(ofSize: 16)
    }()
    
    lazy var timestampFont = {
        return UIFont.systemFont(ofSize: 10)
    }()
    
    open func textFont(_ textMessage: TextMessage, isSelected: Bool) -> UIFont {
        return self.font
    }
    
    open func timestampFont(_ isSelected: Bool) -> UIFont {
        return self.timestampFont
    }
    
    open func textColor(_ textMessage: TextMessage, isSelected: Bool) -> UIColor {
        return textMessage.isIncoming ? UIColor.black : UIColor.white
    }
    
    open func textInsets(_ textMessage: TextMessage, isSelected: Bool) -> UIEdgeInsets {
        return textMessage.isIncoming ? UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15) : UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
    }
    
    open func bubbleImageBorder( _ textMessage: TextMessage, isSelected: Bool) -> UIImage? {
        return self.baseStyle.borderImage(textMessage)
    }
    
    open func bubbleImage(_ textMessage: TextMessage, isSelected: Bool) -> UIImage {
        let showsTail = !textMessage.sameSenderAsLastMessage
        let key = self.imageKey(isIncoming: textMessage.isIncoming, status: textMessage.status, showsTail:showsTail, isSelected: isSelected)
        
        if let image = self.images[key] {
            return image
        } else {
            let templateKey = self.templateKey(isIncoming: textMessage.isIncoming, showsTail: showsTail)
            if let image = self.images[templateKey] {
                let image = self.createImage(templateImage: image, isIncoming: textMessage.isIncoming, status: textMessage.status, isSelected: isSelected)
                self.images[key] = image
                return image
            }
        }
        
        assert(false, "coulnd't find image for this status. ImageKey: \(key)")
        return UIImage()
    }
    
    fileprivate func createImage(templateImage image: UIImage, isIncoming: Bool, status: MessageStatus, isSelected: Bool) -> UIImage {
        var color = isIncoming ? self.baseStyle.baseColorIncoming : self.baseStyle.baseColorOutgoing
        
        switch status {
        case .success:
            break
        case .failed, .sending:
            color = color.bma_blendWithColor(UIColor.white.withAlphaComponent(0.70))
        }
        
        if isSelected {
            color = color.bma_blendWithColor(UIColor.black.withAlphaComponent(0.10))
        }
        
        return image.bma_tintWithColor(color)
    }
    
    fileprivate func imageKey(isIncoming: Bool, status: MessageStatus, showsTail: Bool, isSelected: Bool) -> String {
        let directionKey = isIncoming ? "incoming" : "outgoing"
        let tailKey = showsTail ? "tail" : "notail"
        let statusKey = ChatItem.statusKey(status)
        let highlightedKey = isSelected ? "highlighted" : "normal"
        let key = "\(directionKey)_\(tailKey)_\(statusKey)_\(highlightedKey)"
        return key
    }
    
    fileprivate func templateKey(isIncoming: Bool, showsTail: Bool) -> String {
        let directionKey = isIncoming ? "incoming" : "outgoing"
        let tailKey = showsTail ? "tail" : "notail"
        return "\(directionKey)_\(tailKey)"
    }
}
