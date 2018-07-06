import Foundation
import Chatto

open class PhotoMessageBubbleViewDefaultStyle: PhotoMessageBubbleViewStyleProtocol {
    
    public init () {}
    
    lazy var baseStyle = BaseMessageCollectionViewCellDefaultSyle()
    lazy var images: [String: UIImage] = {
        return [
            "incoming_tail" : UIImage(named: "bubble-incoming-tail", in: Bundle(for: PhotoMessageBubbleViewDefaultStyle.self), compatibleWith: nil)!,
            "incoming_notail" : UIImage(named: "bubble-incoming", in: Bundle(for: PhotoMessageBubbleViewDefaultStyle.self), compatibleWith: nil)!,
            "outgoing_tail" : UIImage(named: "bubble-outgoing-tail", in: Bundle(for: PhotoMessageBubbleViewDefaultStyle.self), compatibleWith: nil)!,
            "outgoing_notail" : UIImage(named: "bubble-outgoing", in: Bundle(for: PhotoMessageBubbleViewDefaultStyle.self), compatibleWith: nil)!,
            ]
    }()
    
    lazy var timestampFont = {
        return UIFont.systemFont(ofSize: 10)
    }()
    
    open func timestampFont(_ isSelected: Bool) -> UIFont {
        return self.timestampFont
    }
    
    open func timestampColor(_ photoMessage: PhotoMessage, isSelected: Bool) -> UIColor {
        return photoMessage.isIncoming ? UIColor.black : UIColor.white
    }
    
    open func textInsets(_ photoMessage: PhotoMessage, isSelected: Bool) -> UIEdgeInsets {
        //return photoMessage.isIncoming ? UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15) : UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
        let margin:CGFloat = 6
        return photoMessage.isIncoming ? UIEdgeInsets(top: margin, left: margin, bottom: 10, right: 12) : UIEdgeInsets(top: margin, left: margin, bottom: 10, right: 12)
    }
    
    open func bubbleImageBorder( _ photoMessage: PhotoMessage, isSelected: Bool) -> UIImage? {
        return self.baseStyle.borderImage(photoMessage)
    }
    
    open func bubbleImage(_ photoMessage: PhotoMessage, isSelected: Bool) -> UIImage {
        let showsTail = !photoMessage.sameSenderAsLastMessage
        let key = self.imageKey(isIncoming: photoMessage.isIncoming, status: photoMessage.status, showsTail:showsTail, isSelected: isSelected)
        
        if let image = self.images[key] {
            return image
        } else {
            let templateKey = self.templateKey(isIncoming: photoMessage.isIncoming, showsTail: showsTail)
            if let image = self.images[templateKey] {
                let image = self.createImage(templateImage: image, isIncoming: photoMessage.isIncoming, status: photoMessage.status, isSelected: isSelected)
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
