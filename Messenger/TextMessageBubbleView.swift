import Foundation

open class TextMessageBubbleView : UIView, MaximumLayoutWidthSpecificable, BackgroundSizingQueryable {
    
    open var preferredMaxLayoutWidth: CGFloat = 0
    open var animationDuration: CFTimeInterval = 0.33
    
    open var viewContext: ViewContext = .normal {
        didSet {
            if self.viewContext == .sizing {
                self.textView.dataDetectorTypes = UIDataDetectorTypes()
                self.textView.isSelectable = false
            } else {
                self.textView.dataDetectorTypes = .all
                self.textView.isSelectable = true
            }
        }
    }
    
    open var bubbleStyle: TextMessageBubbleViewStyleProtocol! {
        didSet {
            self.updateViews()
        }
    }
    
    open var textMessage: TextMessage! {
        didSet {
            self.timestampText = TimeHelper.asMessageDate( textMessage.date )
            self.updateViews()
        }
    }
    
    fileprivate var timestampText: String!
    
    open var selected: Bool = false {
        didSet {
            self.updateViews()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    fileprivate func commonInit() {
        self.addSubview(self.bubbleImageView)
        self.addSubview(self.textView)
        self.addSubview(self.timestampView)
    }
    
    fileprivate lazy var bubbleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.addSubview(self.borderImageView)
        return imageView
    }()
    
    fileprivate var timestampView: UITextView = {
        let textView = TextMessageBubbleView.createTextView()
        textView.dataDetectorTypes = UIDataDetectorTypes()
        return textView
    }()
    
    fileprivate var borderImageView: UIImageView = UIImageView()
    fileprivate var textView: UITextView = {
        return TextMessageBubbleView.createTextView()
    }()
    
    fileprivate class func createTextView() -> MessageTextView {
        let textView = MessageTextView()
        
        textView.backgroundColor = UIColor.clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.dataDetectorTypes = .all
        textView.scrollsToTop = false
        textView.isScrollEnabled = false
        textView.bounces = false
        textView.bouncesZoom = false
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = false
        textView.layoutManager.allowsNonContiguousLayout = true
        textView.isExclusiveTouch = true
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        
        return textView
    }
    
    open fileprivate(set) var isUpdating: Bool = false
    open func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() -> Void)?) {
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
    
    fileprivate func updateViews() {
        if self.viewContext == .sizing { return }
        if isUpdating { return }
        guard let bubbleStyle = self.bubbleStyle, let textMessage = self.textMessage else { return }
        let font = bubbleStyle.textFont(textMessage, isSelected: self.selected)
        let textColor = bubbleStyle.textColor(textMessage, isSelected: self.selected)
        let bubbleImage = bubbleStyle.bubbleImage(textMessage, isSelected: self.selected)
        let borderImage = bubbleStyle.bubbleImageBorder(textMessage, isSelected: self.selected)
        
        if self.textView.font != font { self.textView.font = font}
        if self.textView.text != textMessage.msg.body {self.textView.text = textMessage.msg.body}
        if self.textView.textColor != textColor {
            self.textView.textColor = textColor
            self.textView.linkTextAttributes = [
                NSForegroundColorAttributeName: textColor,
                NSUnderlineStyleAttributeName : NSUnderlineStyle.styleSingle.rawValue
            ]
        }
        if self.bubbleImageView.image != bubbleImage { self.bubbleImageView.image = bubbleImage}
        if self.borderImageView.image != borderImage { self.borderImageView.image = borderImage }
        
        timestampView.text = timestampText
        timestampView.textColor = textColor
        timestampView.font = bubbleStyle.timestampFont( self.selected )
    }
    
    fileprivate func bubbleImage() -> UIImage {
        return bubbleStyle.bubbleImage(textMessage, isSelected: self.selected)
    }
    
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.calculateTextBubbleLayout(preferredMaxLayoutWidth: size.width).size
    }
    
    //
    // MARK:  Layout
    //
    open override func layoutSubviews() {
        super.layoutSubviews()
        let layout = self.calculateTextBubbleLayout(preferredMaxLayoutWidth: self.preferredMaxLayoutWidth)
        self.textView.bma_rect = layout.textFrame
        self.timestampView.bma_rect = layout.timestampFrame
        self.bubbleImageView.bma_rect = layout.bubbleFrame
        self.borderImageView.bma_rect = self.bubbleImageView.bounds
    }
    
    open var layoutCache: NSCache<AnyObject, AnyObject>!
    fileprivate func calculateTextBubbleLayout(preferredMaxLayoutWidth: CGFloat) -> TextBubbleLayoutModel {
        let layoutContext = TextBubbleLayoutModel.LayoutContext(
            text: textMessage.msg.body!,
            textFont: bubbleStyle.textFont(textMessage, isSelected: self.selected),
            timestamp: timestampText,
            timestampFont: bubbleStyle.timestampFont(self.selected),
            textInsets: bubbleStyle.textInsets(textMessage, isSelected: self.selected),
            preferredMaxLayoutWidth: preferredMaxLayoutWidth
        )
        
        if let layoutModel = self.layoutCache.object(forKey: layoutContext.hashValue as AnyObject) as? TextBubbleLayoutModel, layoutModel.layoutContext == layoutContext {
            return layoutModel
        }
        
        let layoutModel = TextBubbleLayoutModel(layoutContext: layoutContext)
        layoutModel.calculateLayout()
        
        self.layoutCache.setObject(layoutModel, forKey: layoutContext.hashValue as AnyObject)
        return layoutModel
    }
    
    open var canCalculateSizeInBackground: Bool {
        return true
    }
}

private final class TextBubbleLayoutModel {
    let layoutContext: LayoutContext
    var textFrame: CGRect = CGRect.zero
    var timestampFrame: CGRect = CGRect.zero
    var bubbleFrame: CGRect = CGRect.zero
    var chatHeadFrame: CGRect = CGRect.zero
    var size: CGSize = CGSize.zero
    
    init(layoutContext: LayoutContext) {
        self.layoutContext = layoutContext
    }
    
    class LayoutContext: Equatable, Hashable {
        let text: String
        let textFont: UIFont
        let timestamp: String?
        let timestampFont: UIFont
        let textInsets: UIEdgeInsets
        let preferredMaxLayoutWidth: CGFloat
        init (text: String, textFont: UIFont, timestamp: String?, timestampFont: UIFont, textInsets: UIEdgeInsets, preferredMaxLayoutWidth: CGFloat) {
            self.text = text
            self.textFont = textFont
            self.timestamp = timestamp
            self.timestampFont = timestampFont
            self.textInsets = textInsets
            self.preferredMaxLayoutWidth = preferredMaxLayoutWidth
        }
        
        var hashValue: Int {
            get {
                return self.text.hashValue ^ self.textInsets.bma_hashValue ^ self.preferredMaxLayoutWidth.hashValue ^ self.textFont.hashValue
                    ^ (timestamp == nil ? 0 : timestamp!.hashValue) ^ timestampFont.hashValue
            }
        }
    }
    
    func calculateLayout() {
        let textInsets = layoutContext.textInsets
        let horizontalInset = textInsets.left + textInsets.right
        let timestampPadding = textInsets.bottom / 2    // vertical space between message text and timestamp
        let maxTextWidth = layoutContext.preferredMaxLayoutWidth - horizontalInset
        
        let textSize = textSizeThatFitsWidth(maxTextWidth)
        
        // handle timestamptext=nil which means dont show a timestamp
        let timestampSize = layoutContext.timestamp == nil ? CGSize.zero : layoutContext.timestamp!.boundingRect(
            with: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [NSFontAttributeName: layoutContext.timestampFont], context:  nil
            ).size.bma_round()
        let timestampHeight = timestampSize.height > 0 ? timestampSize.height + timestampPadding : 0
        
        let widest = max( textSize.width, timestampSize.width )
        let bubbleHeight = textInsets.top + textSize.height + timestampHeight + textInsets.bottom
        let bubbleSize = CGSize( width: widest + horizontalInset, height: bubbleHeight );
        self.bubbleFrame = CGRect(origin: CGPoint.zero, size: bubbleSize)
        
        self.textFrame = CGRect( origin:CGPoint( x: textInsets.left, y: textInsets.top ), size:textSize )
        
        let origin = CGPoint( x: textInsets.left, y: textInsets.top + textSize.height + timestampPadding )
        self.timestampFrame = CGRect( origin:origin, size:timestampSize )
        
        self.size = bubbleSize
    }
    
    /*private func roundUp( size:CGSize ) -> CGSize {
        return CGSizeMake( ceil( size.width ), ceil( size.height ) )
    }*/
    
    fileprivate func textSizeThatFitsWidth(_ width: CGFloat) -> CGSize {
        return self.layoutContext.text.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [NSFontAttributeName: self.layoutContext.textFont], context:  nil
            ).size.bma_round()
    }
}

private func == (lhs: TextBubbleLayoutModel.LayoutContext, rhs: TextBubbleLayoutModel.LayoutContext) -> Bool {
    return lhs.text == rhs.text &&
        lhs.textInsets == rhs.textInsets &&
        lhs.textFont == rhs.textFont &&
        lhs.preferredMaxLayoutWidth == rhs.preferredMaxLayoutWidth
}


/// UITextView with hacks to avoid selection, loupe, define...
private final class MessageTextView: UITextView {
    
    override var canBecomeFirstResponder : Bool {
        return false
    }
    
    override func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if type(of: gestureRecognizer) == UILongPressGestureRecognizer.self && gestureRecognizer.delaysTouchesEnded {
            super.addGestureRecognizer(gestureRecognizer)
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }
}

