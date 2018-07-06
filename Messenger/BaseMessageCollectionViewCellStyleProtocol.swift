import Foundation

public protocol BaseMessageCollectionViewCellStyleProtocol {
    var failedIcon: UIImage { get }
    var failedIconHighlighted: UIImage { get }
    func attributedStringForDate(_ date: String) -> NSAttributedString
}
