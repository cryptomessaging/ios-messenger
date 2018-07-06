import Foundation
import Chatto

public protocol BaseMessageInteractionHandlerProtocol {
    func userDidTapOnFailIcon(_ chatItem: ChatItemProtocol)
    func userDidTapOnChatHead(_ chatItem: ChatItemProtocol)
    func userDidTapOnBubble(_ chatItem: ChatItemProtocol)
    func userDidLongPressOnBubble(_ chatItem: ChatItemProtocol, view: UIView)
}

open class BaseMessagePresenter<ChatItemT,BubbleViewT,InteractionHandlerT>:
    BaseChatItemPresenter<BaseMessageCollectionViewCell<BubbleViewT>> where
    ChatItemT:ChatItemProtocol,
    InteractionHandlerT:BaseMessageInteractionHandlerProtocol,
    BubbleViewT:UIView,BubbleViewT:MaximumLayoutWidthSpecificable, BubbleViewT:BackgroundSizingQueryable {
    
    public typealias CellT = BaseMessageCollectionViewCell<BubbleViewT>
    
    let chatItem: ChatItemT
    let sizingCell: BaseMessageCollectionViewCell<BubbleViewT>
    let interactionHandler: InteractionHandlerT?
    let cellStyle: BaseMessageCollectionViewCellStyleProtocol
    
    public init (
        chatItem: ChatItemT,
        interactionHandler: InteractionHandlerT?,
        sizingCell: BaseMessageCollectionViewCell<BubbleViewT>,
        cellStyle: BaseMessageCollectionViewCellStyleProtocol) {
            self.chatItem = chatItem
            self.interactionHandler = interactionHandler
            self.sizingCell = sizingCell
            self.cellStyle = cellStyle
    }
    
    //  public func configureCell(cell: UICollectionViewCell, decorationAttributes: ChatItemDecorationAttributesProtocol?)
    open override func configureCell(_ cell: UICollectionViewCell, decorationAttributes: ChatItemDecorationAttributesProtocol?) {
        guard let cell = cell as? CellT else {
            assert(false, "Invalid cell given to presenter")
            return
        }
        guard let decorationAttributes = decorationAttributes as? ChatItemDecorationAttributes else {
            assert(false, "Expecting decoration attributes")
            return
        }

        self.configureCell(cell, decorationAttributes: decorationAttributes, animated: false, additionalConfiguration: nil)
    }
    
    var decorationAttributes: ChatItemDecorationAttributes!
    open func configureCell(_ cell: CellT, decorationAttributes: ChatItemDecorationAttributes, animated: Bool, additionalConfiguration: (() -> Void)?) {
        self.decorationAttributes = decorationAttributes
        cell.performBatchUpdates({ () -> Void in
            cell.bubbleView.isUserInteractionEnabled = true // just in case something went wrong while showing UIMenuController
            cell.cellStyle = self.cellStyle
            cell.onBubbleTapped = { [weak self] (cell) in
                guard let sSelf = self else { return }
                sSelf.interactionHandler?.userDidTapOnBubble(sSelf.chatItem)
            }
            cell.onChatHeadTapped = { [weak self] (cell) in
                guard let sSelf = self else { return }
                sSelf.interactionHandler?.userDidTapOnChatHead(sSelf.chatItem)
            }
            cell.onBubbleLongPressed = { [weak self] (cell) in
                guard let sSelf = self else { return }
                sSelf.interactionHandler?.userDidLongPressOnBubble(sSelf.chatItem, view:cell.bubbleView)
            }
            cell.onFailedButtonTapped = { [weak self] (cell) in
                guard let sSelf = self else { return }
                sSelf.interactionHandler?.userDidTapOnFailIcon(sSelf.chatItem)
            }
            additionalConfiguration?()
            }, animated: animated, completion: nil)
    }
    
    open override func heightForCell(maximumWidth width: CGFloat, decorationAttributes: ChatItemDecorationAttributesProtocol?) -> CGFloat {
        guard let decorationAttributes = decorationAttributes as? ChatItemDecorationAttributes else {
            assert(false, "Expecting decoration attributes")
            return 0
        }
        self.configureCell(self.sizingCell, decorationAttributes: decorationAttributes, animated: false, additionalConfiguration: nil)
        return self.sizingCell.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
    }
    
    open override var canCalculateHeightInBackground: Bool {
        return self.sizingCell.canCalculateSizeInBackground
    }
    
    open override func shouldShowMenu() -> Bool {
        guard self.canShowMenu() else { return false }
        guard let cell = self.cell else {
            assert(false, "Investigate -> Fix or remove assert")
            return false
        }
        cell.bubbleView.isUserInteractionEnabled = false // This is a hack for UITextView, shouldn't harm to all bubbles
        NotificationCenter.default.addObserver(self, selector: #selector(willShowMenu), name: NSNotification.Name.UIMenuControllerWillShowMenu, object: nil)
        return true
    }

    @objc
    func willShowMenu(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIMenuControllerWillShowMenu, object: nil)
        guard let cell = self.cell, let menuController = notification.object as? UIMenuController else {
            assert(false, "Investigate -> Fix or remove assert")
            return
        }
        cell.bubbleView.isUserInteractionEnabled = true
        menuController.setMenuVisible(false, animated: false)
        menuController.setTargetRect(cell.bubbleView.bounds, in: cell.bubbleView)
        menuController.setMenuVisible(true, animated: true)
    }

    open func canShowMenu() -> Bool {
        // Override in subclass
        return false
    }
}
