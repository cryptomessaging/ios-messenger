import Foundation

open class PhotoMessageBubbleView : UIView, MaximumLayoutWidthSpecificable, BackgroundSizingQueryable {
    
    open var preferredMaxLayoutWidth: CGFloat = 0
    open var animationDuration: CFTimeInterval = 0.33
    
    static let fetchingMediaIcon = UIImage(named:"Fetching Media")!
    static let unknownMediaIcon = UIImage(named:"Unknown Media")!
    
    open var viewContext: ViewContext = .normal {
        didSet {
            if self.viewContext == .sizing {
                //self.textView.dataDetectorTypes = UIDataDetectorTypes()
                //self.textView.isSelectable = false
            } else {
                //self.textView.dataDetectorTypes = .all
                //self.textView.isSelectable = true
            }
        }
    }
    
    open var bubbleStyle: PhotoMessageBubbleViewStyleProtocol! {
        didSet {
            self.updateViews()
        }
    }
    
    open var photoMessage: PhotoMessage! {
        willSet(newMessage) {
            if hasPhotoChanged(newMessage) {
                photoView.image = PhotoMessageBubbleView.fetchingMediaIcon
                photoView.contentMode = .center
            }
        }
        didSet {
            self.timestampText = TimeHelper.asMessageDate( photoMessage.date )
            self.updateViews()
        }
    }
    
    func hasPhotoChanged(_ newMessage:PhotoMessage) -> Bool {
        if photoMessage == nil {
            return true
        }

        // if anything has changed, return true
        let old = photoMessage.msg
        let new = newMessage.msg
        return old.tid != new.tid
            || old.from != new.from
            || firstMediaCreated(old) != firstMediaCreated(new)
    }
    
    func firstMediaCreated(_ msg:ChatMessage) -> String? {
        if let media = msg.media, let first = media.first, let meta = first.meta {
            return meta["created"]
        } else {
            return nil
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
        self.addSubview(self.photoView)
        self.addSubview(self.timestampView)
    }
    
    fileprivate lazy var bubbleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.addSubview(self.borderImageView)
        return imageView
    }()
    
    fileprivate var timestampView: UITextView = {
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
        textView.dataDetectorTypes = UIDataDetectorTypes()
        return textView
    }()
    
    fileprivate var borderImageView: UIImageView = UIImageView()
    
    fileprivate var photoView = ReusableImageView()
    
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
        guard let bubbleStyle = self.bubbleStyle, let photoMessage = self.photoMessage else { return }
        
        let bubbleImage = bubbleStyle.bubbleImage(photoMessage, isSelected: self.selected)
        if self.bubbleImageView.image != bubbleImage { self.bubbleImageView.image = bubbleImage }
        
        let borderImage = bubbleStyle.bubbleImageBorder(photoMessage, isSelected: self.selected)
        if self.borderImageView.image != borderImage { self.borderImageView.image = borderImage }
        
        let chatMessage = photoMessage.msg
        if isPhoto( chatMessage.media ) {
            let size = PhotoMessageBubbleView.bestMediaPreviewSize(media: chatMessage.media![0])
            ImageHelper.fetchChatImage(msg:chatMessage, index:0, ofSize:size, forImageView:photoView)
        } else {
            photoView.image = PhotoMessageBubbleView.unknownMediaIcon
        }
        
        timestampView.text = timestampText
        timestampView.textColor = bubbleStyle.timestampColor(photoMessage, isSelected: self.selected)
        timestampView.font = bubbleStyle.timestampFont( self.selected )
    }
    
    func isPhoto( _ media:[Media]? ) -> Bool {
        if let first = media?.first {
            return first.type == "image/jpeg"
        } else {
            return false
        }
    }
    
    class func bestMediaPreviewSize(media:Media) -> String {
        let photoSize = ImageHelper.downsize(media:media, maxSide: 240.0)
        return ImageHelper.asWidthXHeight( size: photoSize )
    }
    
    fileprivate func bubbleImage() -> UIImage {
        return bubbleStyle.bubbleImage(photoMessage, isSelected: self.selected)
    }
    
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.calculatePhotoBubbleLayout(preferredMaxLayoutWidth: size.width).size
    }
    
    //
    // MARK:  Layout
    //
    open override func layoutSubviews() {
        super.layoutSubviews()
        let layout = self.calculatePhotoBubbleLayout(preferredMaxLayoutWidth: self.preferredMaxLayoutWidth)
        self.photoView.bma_rect = layout.photoFrame
        self.timestampView.bma_rect = layout.timestampFrame
        self.bubbleImageView.bma_rect = layout.bubbleFrame
        self.borderImageView.bma_rect = self.bubbleImageView.bounds
    }
    
    open var layoutCache: NSCache<AnyObject, AnyObject>!
    fileprivate func calculatePhotoBubbleLayout(preferredMaxLayoutWidth: CGFloat) -> PhotoBubbleLayoutModel {
        let layoutContext = PhotoBubbleLayoutModel.LayoutContext(
            photo: photoMessage.msg.media![0],
            timestamp: timestampText,
            timestampFont: bubbleStyle.timestampFont(self.selected),
            textInsets: bubbleStyle.textInsets(photoMessage, isSelected: self.selected),
            preferredMaxLayoutWidth: preferredMaxLayoutWidth
        )
        
        if let layoutModel = self.layoutCache.object(forKey: layoutContext.hashValue as AnyObject) as? PhotoBubbleLayoutModel, layoutModel.layoutContext == layoutContext {
            return layoutModel
        }
        
        let layoutModel = PhotoBubbleLayoutModel(layoutContext: layoutContext)
        layoutModel.calculateLayout()
        
        self.layoutCache.setObject(layoutModel, forKey: layoutContext.hashValue as AnyObject)
        return layoutModel
    }
    
    open var canCalculateSizeInBackground: Bool {
        return true
    }
}

private final class PhotoBubbleLayoutModel {
    let layoutContext: LayoutContext
    var photoFrame: CGRect = CGRect.zero
    var timestampFrame: CGRect = CGRect.zero
    var bubbleFrame: CGRect = CGRect.zero
    var chatHeadFrame: CGRect = CGRect.zero
    var size: CGSize = CGSize.zero
    
    init(layoutContext: LayoutContext) {
        self.layoutContext = layoutContext
    }
    
    class LayoutContext: Equatable, Hashable {
        let photoMedia: Media
        let timestamp: String?
        let timestampFont: UIFont
        let textInsets: UIEdgeInsets
        let preferredMaxLayoutWidth: CGFloat
        init ( photo:Media, timestamp: String?, timestampFont: UIFont, textInsets: UIEdgeInsets, preferredMaxLayoutWidth: CGFloat) {
            self.photoMedia = photo
            self.timestamp = timestamp
            self.timestampFont = timestampFont
            self.textInsets = textInsets
            self.preferredMaxLayoutWidth = preferredMaxLayoutWidth
        }
        
        var hashValue: Int {
            get {
                return self.photoMedia.hashValue ^ self.textInsets.bma_hashValue ^ self.preferredMaxLayoutWidth.hashValue
                    ^ (timestamp == nil ? 0 : timestamp!.hashValue) ^ timestampFont.hashValue
            }
        }
    }
    
    func calculateLayout() {
        let textInsets = layoutContext.textInsets
        let horizontalInset = textInsets.left + textInsets.right
        let timestampPadding = textInsets.bottom / 2    // vertical space between message text and timestamp
        let maxTextWidth = layoutContext.preferredMaxLayoutWidth - horizontalInset
        
        let photoSize = ImageHelper.downsize(media:layoutContext.photoMedia, maxSide: 240.0)
        
        // handle timestamptext=nil which means dont show a timestamp
        let timestampSize = layoutContext.timestamp == nil ? CGSize.zero : layoutContext.timestamp!.boundingRect(
            with: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [NSFontAttributeName: layoutContext.timestampFont], context:  nil
            ).size.bma_round()
        let timestampHeight = timestampSize.height > 0 ? timestampSize.height + timestampPadding : 0
        
        let widest = max( photoSize.width, timestampSize.width )
        let bubbleHeight = textInsets.top + photoSize.height + timestampHeight + textInsets.bottom
        let bubbleSize = CGSize( width: widest + horizontalInset, height: bubbleHeight );
        self.bubbleFrame = CGRect(origin: CGPoint.zero, size: bubbleSize)
        
        self.photoFrame = CGRect( origin:CGPoint( x: textInsets.left, y: textInsets.top ), size:photoSize )
        
        let origin = CGPoint( x: textInsets.left, y: textInsets.top + photoSize.height + timestampPadding )
        self.timestampFrame = CGRect( origin:origin, size:timestampSize )
        
        self.size = bubbleSize
    }
}

private func == (lhs: PhotoBubbleLayoutModel.LayoutContext, rhs: PhotoBubbleLayoutModel.LayoutContext) -> Bool {
    return lhs.photoMedia.hashValue == rhs.photoMedia.hashValue &&
        lhs.textInsets == rhs.textInsets &&
        lhs.timestamp == rhs.timestamp &&
        lhs.preferredMaxLayoutWidth == rhs.preferredMaxLayoutWidth
}


// UITextView with hacks to avoid selection, loupe, define...
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
