import UIKit
import Chatto

public struct BaseMessageCollectionViewCellLayoutConstants {
    let horizontalMargin: CGFloat = 11
    let horizontalInterspacing: CGFloat = 4
    let maxContainerWidthPercentageForBubbleView: CGFloat = 0.68
}

/**
 Base class for message cells
 
 Provides:
 
 - Reveleable timestamp layout logic
 - Failed view
 - Incoming/outcoming layout
 
 Subclasses responsability
 - Implement createBubbleView
 - Have a BubbleViewType that responds properly to sizeThatFits:
 */

open class BaseMessageCollectionViewCell<BubbleViewType>: UICollectionViewCell, BackgroundSizingQueryable, AccessoryViewRevealable, UIGestureRecognizerDelegate where BubbleViewType:UIView, BubbleViewType:MaximumLayoutWidthSpecificable, BubbleViewType: BackgroundSizingQueryable {
    
    public func preferredOffsetToRevealAccessoryView() -> CGFloat? {
        return 0
    }
    public var allowAccessoryViewRevealing = false
    
    open var animationDuration: CFTimeInterval = 0.33
    open var viewContext: ViewContext = .normal
    
    open fileprivate(set) var isUpdating: Bool = false
    
    open var chatItem: ChatItem! {
        didSet {
            updateViews()
        }
    }
    
    open var dateFormatter = DateFormatter()
    
    open lazy var date: String = {
        return self.dateFormatter.string(from: self.chatItem.date as Date)
    }()
    
    var failedIcon: UIImage!
    var failedIconHighlighted: UIImage!
    open var cellStyle: BaseMessageCollectionViewCellStyleProtocol! {
        didSet {
            self.failedIcon = self.cellStyle.failedIcon
            self.failedIconHighlighted = self.cellStyle.failedIconHighlighted
            self.updateViews()
        }
    }
    
    override open var isSelected: Bool {
        didSet {
            if oldValue != self.isSelected {
                self.updateViews()
            }
        }
    }
    
    var layoutConstants = BaseMessageCollectionViewCellLayoutConstants() {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    open var canCalculateSizeInBackground: Bool {
        return self.bubbleView.canCalculateSizeInBackground
    }
    
    open fileprivate(set) var bubbleView: BubbleViewType!
    open func createBubbleView() -> BubbleViewType! {
        assert(false, "Override in subclass")
        return nil
    }
    
    //
    // MARK: Chat heads
    //
    
    fileprivate var cardId:String?  // chat head card id, or nil for none
    
    fileprivate var chatHeadImageView: UIImageView = {
        let frame = CGRect(x: 0, y: 0, width: UIConstants.CardCoverDiameter, height: UIConstants.CardCoverDiameter)
        let view = ReusableImageView(frame:frame)
        view.isUserInteractionEnabled = true
        ImageHelper.round(view)
        return view
    }()
    
    //
    // MARK: Callbacks
    //
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    fileprivate func commonInit() {
        bubbleView = self.createBubbleView()
        bubbleView.addGestureRecognizer(self.bubbleTapGestureRecognizer)
        bubbleView.addGestureRecognizer(self.longPressGestureRecognizer)
        contentView.addSubview(bubbleView)
        
        contentView.addSubview(failedButton)
        
        chatHeadImageView.addGestureRecognizer(self.chatHeadTapGestureRecognizer)
        contentView.addSubview(chatHeadImageView)
        
        contentView.isExclusiveTouch = true
        isExclusiveTouch = true
    }
    
    open func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() ->())?) {
        self.isUpdating = true
        let updateAndRefreshViews = {
            updateClosure()
            self.isUpdating = false
            self.updateViews()
            if animated {
                self.layoutIfNeeded()
            }
        }
        if animated {
            UIView.animate(withDuration: self.animationDuration, animations: updateAndRefreshViews, completion: { (finished) -> Void in
                completion?()
            })
        } else {
            updateAndRefreshViews()
        }
    }
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        self.removeAccessoryView()
    }
    
    //
    // MARK: Gesture handling
    //
    
    open fileprivate(set) lazy var chatHeadTapGestureRecognizer: UITapGestureRecognizer = {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(chatHeadTapped))
        return tapGestureRecognizer
    }()
    
    open fileprivate(set) lazy var bubbleTapGestureRecognizer: UITapGestureRecognizer = {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(bubbleTapped))
        return tapGestureRecognizer
    }()
    
    open fileprivate (set) lazy var longPressGestureRecognizer: UILongPressGestureRecognizer = {
        let longpressGestureRecognizer = UILongPressGestureRecognizer(target: self, action:#selector(doBubbleLongPressed))
        longpressGestureRecognizer.delegate = self
        return longpressGestureRecognizer
    }()

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return self.bubbleView.bounds.contains(touch.location(in: self.bubbleView))
    }

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer === self.longPressGestureRecognizer
    }

    fileprivate lazy var failedButton: UIButton = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(failedButtonTapped), for: .touchUpInside)
        return button
    }()

    //
    // MARK: View model binding
    //
    
    final fileprivate func updateViews() {
        if self.viewContext == .sizing { return }
        if self.isUpdating { return }
        guard let message = self.chatItem, let style = self.cellStyle else { return }
        if message.status == .failed {
            self.failedButton.setImage(self.failedIcon, for: UIControlState())
            self.failedButton.setImage(self.failedIconHighlighted, for: .highlighted)
            self.failedButton.alpha = 1
        } else {
            self.failedButton.alpha = 0
        }
        self.accessoryTimestamp?.attributedText = style.attributedStringForDate(date)
        
        // update chat head?
        let msg = chatItem.msg
        if chatItem.sameSenderAsLastMessage {
            chatHeadImageView.image = nil    // don't show an image
        } else if msg.from != cardId || chatHeadImageView.image == nil {     // has the card changed?
            cardId = msg.from
            ImageHelper.fetchThreadCardCoverImage(msg.tid!, cid:msg.from!, ofSize:"c100", forImageView:chatHeadImageView)
        }

        self.setNeedsLayout()
    }

    //
    // MARK: layout
    //
    
    open override func layoutSubviews() {
        super.layoutSubviews()

        let layoutModel = self.calculateLayout(availableWidth: self.contentView.bounds.width)
        self.failedButton.bma_rect = layoutModel.failedViewFrame
        self.chatHeadImageView.bma_rect = layoutModel.chatHeadFrame
        
        self.bubbleView.bma_rect = layoutModel.bubbleViewFrame
        self.bubbleView.preferredMaxLayoutWidth = layoutModel.preferredMaxWidthForBubble
        self.bubbleView.layoutIfNeeded()

        // TODO: refactor accessoryView?

        if let accessoryView = self.accessoryTimestamp {
            accessoryView.bounds = CGRect(origin: CGPoint.zero, size: accessoryView.intrinsicContentSize)
            let accessoryViewWidth = accessoryView.bounds.width
            let accessoryViewMargin: CGFloat = 10
            let leftDisplacement = max(0, min(self.timestampMaxVisibleOffset, accessoryViewWidth + accessoryViewMargin))
            var contentViewframe = self.contentView.frame
            if self.chatItem.isIncoming {
                contentViewframe.origin = CGPoint.zero
            } else {
                contentViewframe.origin.x = -leftDisplacement
            }
            self.contentView.frame = contentViewframe
            accessoryView.center = CGPoint(x: self.bounds.width - leftDisplacement + accessoryViewWidth / 2, y: self.contentView.center.y)
        }
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.calculateLayout(availableWidth: size.width).size
    }

    fileprivate func calculateLayout(availableWidth: CGFloat) -> BaseMessageLayoutModel {
        let parameters = BaseMessageLayoutModelParameters(
            containerWidth: availableWidth,
            horizontalMargin: layoutConstants.horizontalMargin,
            horizontalInterspacing: layoutConstants.horizontalInterspacing,
            failedButtonSize: failedIcon.size,
            maxContainerWidthPercentageForBubbleView: layoutConstants.maxContainerWidthPercentageForBubbleView,
            bubbleView: bubbleView,
            chatHeadImageView: chatHeadImageView,
            isIncoming: chatItem.isIncoming,
            isFailed: chatItem.status == .failed
        )
        var layoutModel = BaseMessageLayoutModel()
        layoutModel.calculateLayout(parameters: parameters)
        return layoutModel
    }

    //
    // MARK: timestamp revealing
    //
    
    var timestampMaxVisibleOffset: CGFloat = 0 {
        didSet {
            self.setNeedsLayout()
        }
    }
    var accessoryTimestamp: UILabel?
    open func revealAccessoryView(withOffset offset: CGFloat, animated: Bool) {
        if self.accessoryTimestamp == nil {
            if offset > 0 {
                let accessoryTimestamp = UILabel()
                accessoryTimestamp.attributedText = self.cellStyle?.attributedStringForDate(date)
                self.addSubview(accessoryTimestamp)
                self.accessoryTimestamp = accessoryTimestamp
                self.layoutIfNeeded()
            }

            if animated {
                UIView.animate(withDuration: self.animationDuration, animations: { () -> Void in
                    self.timestampMaxVisibleOffset = offset
                    self.layoutIfNeeded()
                })
            } else {
                self.timestampMaxVisibleOffset = offset
            }
        } else {
            if animated {
                UIView.animate(withDuration: self.animationDuration, animations: { () -> Void in
                    self.timestampMaxVisibleOffset = offset
                    self.layoutIfNeeded()
                    }, completion: { (finished) -> Void in
                        if offset == 0 {
                            self.removeAccessoryView()
                        }
                })

            } else {
                self.timestampMaxVisibleOffset = offset
            }
        }
    }

    func removeAccessoryView() {
        self.accessoryTimestamp?.removeFromSuperview()
        self.accessoryTimestamp = nil
    }

    //
    // MARK: User interaction
    //
    
    open var onFailedButtonTapped: ((_ cell: BaseMessageCollectionViewCell) -> Void)?
    @objc
    func failedButtonTapped() {
        self.onFailedButtonTapped?(self)
    }

    open var onBubbleTapped: ((_ cell: BaseMessageCollectionViewCell) -> Void)?
    @objc
    func bubbleTapped(_ tapGestureRecognizer: UITapGestureRecognizer) {
        self.onBubbleTapped?(self)
    }
    
    open var onChatHeadTapped: ((_ cell: BaseMessageCollectionViewCell) -> Void)?
    @objc
    func chatHeadTapped(_ tapGestureRecognizer: UITapGestureRecognizer) {
        self.onChatHeadTapped?(self)
    }

    open var onBubbleLongPressed: ((_ cell: BaseMessageCollectionViewCell) -> Void)?
    
    @objc
    fileprivate func bubbleLongPressed(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        if longPressGestureRecognizer.state == .began {
            self.doBubbleLongPressed()
        }
    }

    func doBubbleLongPressed() {
        self.onBubbleLongPressed?(self)
    }
}
