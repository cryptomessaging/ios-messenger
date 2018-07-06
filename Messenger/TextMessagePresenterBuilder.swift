import Foundation
import Chatto

open class TextMessagePresenterBuilder: ChatItemPresenterBuilderProtocol {
    
    fileprivate let layoutCache = NSCache<AnyObject, AnyObject>()
    fileprivate lazy var bubbleStyle = TextMessageBubbleViewDefaultStyle()
    fileprivate lazy var cellStyle = BaseMessageCollectionViewCellDefaultSyle()
    fileprivate var interactionHandler:ChatMessageInteractionHandler
    
    fileprivate lazy var sizingCell: TextMessageCollectionViewCell = {
        var cell: TextMessageCollectionViewCell? = nil
        
        if Thread.isMainThread {
            cell = TextMessageCollectionViewCell.sizingCell()
        } else {
            DispatchQueue.main.sync(execute: {
                cell = TextMessageCollectionViewCell.sizingCell()
            })
        }
        
        return cell!
    }()
    
    init(interactionHandler:ChatMessageInteractionHandler) {
        self.interactionHandler = interactionHandler
    }
    
    open func canHandleChatItem(_ chatItem: ChatItemProtocol) -> Bool {
        return chatItem.type == TextMessage.Constant.ItemType
    }
    
    open func createPresenterWithChatItem(_ chatItem: ChatItemProtocol) -> ChatItemPresenterProtocol {
        let msg = chatItem as! TextMessage
        return TextMessagePresenter(textMessage:msg, interactionHandler:interactionHandler, sizingCell:sizingCell
            , cellStyle:cellStyle, bubbleStyle:bubbleStyle, layoutCache:layoutCache)
    }
    
    open var presenterType: ChatItemPresenterProtocol.Type {
        return TextMessagePresenter.self
    }
}
