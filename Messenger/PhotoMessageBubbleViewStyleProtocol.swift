import Foundation

public protocol PhotoMessageBubbleViewStyleProtocol {
    func bubbleImage(_ photoMessage: PhotoMessage, isSelected: Bool) -> UIImage
    func bubbleImageBorder(_ photoMessage: PhotoMessage, isSelected: Bool) -> UIImage?
    func timestampFont( _ isSelected: Bool) -> UIFont
    func timestampColor(_ photoMessage: PhotoMessage, isSelected: Bool) -> UIColor
    func textInsets(_ photoMessage: PhotoMessage, isSelected: Bool) -> UIEdgeInsets
}
