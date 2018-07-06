import Foundation
import Chatto

open class PhotoMessagePresenterBuilder: ChatItemPresenterBuilderProtocol {
    
    fileprivate let layoutCache = NSCache<AnyObject, AnyObject>()
    fileprivate lazy var bubbleStyle = PhotoMessageBubbleViewDefaultStyle()
    fileprivate lazy var cellStyle = BaseMessageCollectionViewCellDefaultSyle()
    fileprivate var interactionHandler:ChatMessageInteractionHandler
    
    fileprivate lazy var sizingCell: PhotoMessageCollectionViewCell = {
        var cell: PhotoMessageCollectionViewCell? = nil
        
        if Thread.isMainThread {
            cell = PhotoMessageCollectionViewCell.sizingCell()
        } else {
            DispatchQueue.main.sync(execute: {
                cell = PhotoMessageCollectionViewCell.sizingCell()
            })
        }
        
        return cell!
    }()
    
    init(interactionHandler:ChatMessageInteractionHandler) {
        self.interactionHandler = interactionHandler
    }
    
    open func canHandleChatItem(_ chatItem: ChatItemProtocol) -> Bool {
        return chatItem.type == PhotoMessage.Constant.ItemType
    }
    
    open func createPresenterWithChatItem(_ chatItem: ChatItemProtocol) -> ChatItemPresenterProtocol {
        let msg = chatItem as! PhotoMessage
        return PhotoMessagePresenter(photoMessage:msg, interactionHandler:interactionHandler, sizingCell:sizingCell
            , cellStyle:cellStyle, bubbleStyle:bubbleStyle, layoutCache:layoutCache)
    }
    
    open var presenterType: ChatItemPresenterProtocol.Type {
        return PhotoMessagePresenter.self
    }
}

