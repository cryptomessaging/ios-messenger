import Foundation
import Chatto

class TextMessagePresenter: BaseMessagePresenter<TextMessage,TextMessageBubbleView,ChatMessageInteractionHandler> {
    //public var canCalculateHeightInBackground = false
    
    let layoutCache:NSCache<AnyObject, AnyObject>
    let textMessage:TextMessage
    let bubbleStyle:TextMessageBubbleViewStyleProtocol
    
    init(textMessage:TextMessage, interactionHandler:ChatMessageInteractionHandler, sizingCell:TextMessageCollectionViewCell, cellStyle:BaseMessageCollectionViewCellStyleProtocol, bubbleStyle:TextMessageBubbleViewStyleProtocol, layoutCache:NSCache<AnyObject, AnyObject>) {
        self.textMessage = textMessage
        self.layoutCache = layoutCache
        self.bubbleStyle = bubbleStyle
        super.init( chatItem: textMessage, interactionHandler:interactionHandler, sizingCell:sizingCell, cellStyle:cellStyle)
    }
    
    open override static func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(TextMessageCollectionViewCell.self, forCellWithReuseIdentifier: "motext-message-incoming")
        collectionView.register(TextMessageCollectionViewCell.self, forCellWithReuseIdentifier: "motext-message-outcoming")
    }
    
    open override func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = chatItem.isIncoming ? "motext-message-incoming" : "motext-message-outcoming"
        return collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
    }
    
    open override func configureCell(_ cell: CellT, decorationAttributes: ChatItemDecorationAttributes, animated: Bool, additionalConfiguration: (() -> Void)?) {
        guard let cell = cell as? TextMessageCollectionViewCell else {
            assert(false, "Invalid cell received")
            return
        }

        super.configureCell(cell, decorationAttributes: decorationAttributes, animated:animated ) {
            cell.bubbleView.textMessage = self.textMessage
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
