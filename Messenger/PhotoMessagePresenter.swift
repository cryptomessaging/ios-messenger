import Foundation
import Chatto

class PhotoMessagePresenter: BaseMessagePresenter<PhotoMessage,PhotoMessageBubbleView,ChatMessageInteractionHandler> {
    //public var canCalculateHeightInBackground = false
    
    let layoutCache:NSCache<AnyObject, AnyObject>
    let photoMessage:PhotoMessage
    let bubbleStyle:PhotoMessageBubbleViewStyleProtocol
    
    init(photoMessage:PhotoMessage, interactionHandler:ChatMessageInteractionHandler, sizingCell:PhotoMessageCollectionViewCell, cellStyle:BaseMessageCollectionViewCellStyleProtocol, bubbleStyle:PhotoMessageBubbleViewStyleProtocol, layoutCache:NSCache<AnyObject, AnyObject>) {
        self.photoMessage = photoMessage
        self.layoutCache = layoutCache
        self.bubbleStyle = bubbleStyle
        super.init( chatItem: photoMessage, interactionHandler:interactionHandler, sizingCell:sizingCell, cellStyle:cellStyle)
    }
    
    open override static func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(PhotoMessageCollectionViewCell.self, forCellWithReuseIdentifier: "mophoto-message-incoming")
        collectionView.register(PhotoMessageCollectionViewCell.self, forCellWithReuseIdentifier: "mophoto-message-outcoming")
    }
    
    open override func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = chatItem.isIncoming ? "mophoto-message-incoming" : "mophoto-message-outcoming"
        return collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
    }
    
    open override func configureCell(_ cell: CellT, decorationAttributes: ChatItemDecorationAttributes, animated: Bool, additionalConfiguration: (() -> Void)?) {
        guard let cell = cell as? PhotoMessageCollectionViewCell else {
            assert(false, "Invalid cell received")
            return
        }
        
        super.configureCell(cell, decorationAttributes: decorationAttributes, animated:animated ) {
            cell.bubbleView.photoMessage = self.photoMessage
            cell.layoutCache = self.layoutCache
            
            cell.chatItem = self.chatItem
            cell.bubbleStyle = self.bubbleStyle
            additionalConfiguration?()
        }
    }
    
    /*
     func cellWillBeShown(cell: UICollectionViewCell) // optional
     func cellWasHidden(cell: UICollectionViewCell) // optional
     func shouldShowMenu() -> Bool // optional. Default is false
     func canPerformMenuControllerAction(action: Selector) -> Bool // optional. Default is false
     func performMenuControllerAction(action: Selector) // optional
     */
}
