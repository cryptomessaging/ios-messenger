import Foundation
import UIKit

public final class TextMessageCollectionViewCell: BaseMessageCollectionViewCell<TextMessageBubbleView> {
    
    public static func sizingCell() -> TextMessageCollectionViewCell? {
        let cell = TextMessageCollectionViewCell(frame: CGRect.zero)
        cell.viewContext = .sizing
        return cell
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Subclassing (view creation)
    
    override public func createBubbleView() -> TextMessageBubbleView {
        return TextMessageBubbleView()
    }
    
    public override func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() -> Void)?) {
        super.performBatchUpdates({ () -> Void in
            self.bubbleView.performBatchUpdates(updateClosure, animated: false, completion: nil)
            }, animated: animated, completion: completion)
    }
    
    // MARK: Property forwarding
    
    override public var viewContext: ViewContext {
        didSet {
            self.bubbleView.viewContext = self.viewContext
        }
    }
    
    public var bubbleStyle: TextMessageBubbleViewStyleProtocol! {
        didSet {
            self.bubbleView.bubbleStyle = self.bubbleStyle
        }
    }
    
    override public var isSelected: Bool {
        didSet {
            self.bubbleView.selected = self.isSelected
        }
    }
    
    public var layoutCache: NSCache<AnyObject, AnyObject>! {
        didSet {
            self.bubbleView.layoutCache = self.layoutCache
        }
    }
}

