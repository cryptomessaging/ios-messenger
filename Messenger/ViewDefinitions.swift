import Foundation

public enum ViewContext {
    case normal
    case sizing // You may skip some cell updates for faster sizing
}

public protocol MaximumLayoutWidthSpecificable {
    var preferredMaxLayoutWidth: CGFloat { get set }
}

public protocol BackgroundSizingQueryable {
    var canCalculateSizeInBackground: Bool { get }
}
