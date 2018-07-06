import Foundation
import UIKit

public final class PhotoMessageCollectionViewCell: BaseMessageCollectionViewCell<PhotoMessageBubbleView> {
    
    public static func sizingCell() -> PhotoMessageCollectionViewCell? {
        let cell = PhotoMessageCollectionViewCell(frame: CGRect.zero)
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
    
    override public func createBubbleView() -> PhotoMessageBubbleView {
        return PhotoMessageBubbleView()
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
    
    public var bubbleStyle: PhotoMessageBubbleViewStyleProtocol! {
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
