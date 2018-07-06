import Foundation

import UIKit

open class BaseMessageCollectionViewCellDefaultSyle: BaseMessageCollectionViewCellStyleProtocol {
    
    public init () {}
    
    lazy var baseColorIncoming = UIColor.bma_color(rgb: 0xE6ECF2)
    lazy var baseColorOutgoing = UIColor.bma_color(rgb: 0x4594ff) //0x007aff)
    
    lazy var borderIncomingTail: UIImage = {
        return UIImage(named: "bubble-incoming-border-tail", in: Bundle(for: type(of: self)), compatibleWith: nil)!
    }()
    
    lazy var borderIncomingNoTail: UIImage = {
        return UIImage(named: "bubble-incoming-border", in: Bundle(for: type(of: self)), compatibleWith: nil)!
    }()
    
    lazy var borderOutgoingTail: UIImage = {
        return UIImage(named: "bubble-outgoing-border-tail", in: Bundle(for: type(of: self)), compatibleWith: nil)!
    }()
    
    lazy var borderOutgoingNoTail: UIImage = {
        return UIImage(named: "bubble-outgoing-border", in: Bundle(for: type(of: self)), compatibleWith: nil)!
    }()
    
    open lazy var failedIcon: UIImage = {
        return UIImage(named: "base-message-failed-icon", in: Bundle(for: type(of: self)), compatibleWith: nil)!
    }()
    
    open lazy var failedIconHighlighted: UIImage = {
        return self.failedIcon.bma_blendWithColor(UIColor.black.withAlphaComponent(0.10))
    }()
    
    fileprivate lazy var dateFont = {
        return UIFont.systemFont(ofSize: 12.0)
    }()
    
    open func attributedStringForDate(_ date: String) -> NSAttributedString {
        let attributes = [NSFontAttributeName : self.dateFont]
        return NSAttributedString(string: date, attributes: attributes)
    }
    
    func borderImage(_ chatItem:ChatItem) -> UIImage? {
        switch (chatItem.isIncoming, !chatItem.sameSenderAsLastMessage) {
        case (true, true):
            return self.borderIncomingTail
        case (true, false):
            return self.borderIncomingNoTail
        case (false, true):
            return self.borderOutgoingTail
        case (false, false):
            return self.borderOutgoingNoTail
        }
    }
}

