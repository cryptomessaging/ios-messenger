import Foundation

public protocol TextMessageBubbleViewStyleProtocol {
    func bubbleImage(_ textMessage: TextMessage, isSelected: Bool) -> UIImage
    func bubbleImageBorder(_ textMessage: TextMessage, isSelected: Bool) -> UIImage?
    func textFont(_ textMessage: TextMessage, isSelected: Bool) -> UIFont
    func timestampFont( _ isSelected: Bool) -> UIFont
    func textColor(_ textMessage: TextMessage, isSelected: Bool) -> UIColor
    func textInsets(_ textMessage: TextMessage, isSelected: Bool) -> UIEdgeInsets
}
