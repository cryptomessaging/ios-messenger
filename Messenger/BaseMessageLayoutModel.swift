import Foundation

struct BaseMessageLayoutModelParameters {
    let containerWidth: CGFloat
    let horizontalMargin: CGFloat
    let horizontalInterspacing: CGFloat
    let failedButtonSize: CGSize
    let maxContainerWidthPercentageForBubbleView: CGFloat // in [0, 1]
    let bubbleView: UIView
    let chatHeadImageView: UIImageView
    let isIncoming: Bool
    let isFailed: Bool
}

struct BaseMessageLayoutModel {
    fileprivate (set) var size = CGSize.zero
    fileprivate (set) var failedViewFrame = CGRect.zero
    fileprivate (set) var bubbleViewFrame = CGRect.zero
    fileprivate (set) var chatHeadFrame = CGRect.zero
    fileprivate (set) var preferredMaxWidthForBubble: CGFloat = 0
    
    mutating func calculateLayout(parameters: BaseMessageLayoutModelParameters) {
        let containerWidth = parameters.containerWidth
        let isIncoming = parameters.isIncoming
        let isFailed = parameters.isFailed
        let failedButtonSize = parameters.failedButtonSize
        let bubbleView = parameters.bubbleView
        let horizontalMargin = parameters.horizontalMargin
        let horizontalInterspacing = parameters.horizontalInterspacing
        
        chatHeadFrame = parameters.chatHeadImageView.frame
        let chatHeadWidth = chatHeadFrame.width
        
        let preferredWidthForBubble = containerWidth * parameters.maxContainerWidthPercentageForBubbleView - chatHeadWidth
        let bubbleSize = bubbleView.sizeThatFits(CGSize(width: preferredWidthForBubble, height: CGFloat.greatestFiniteMagnitude))
        let containerRect = CGRect(origin: CGPoint.zero, size: CGSize(width: containerWidth, height: bubbleSize.height))
        
        bubbleViewFrame = bubbleSize.bma_rect(inContainer: containerRect, xAlignament: .center, yAlignment: .center, dx: 0, dy: 0)
        failedViewFrame = failedButtonSize.bma_rect(inContainer: containerRect, xAlignament: .center, yAlignment: .center, dx: 0, dy: 0)
        
        // Adjust horizontal positions
        
        var currentX: CGFloat = 0
        if isIncoming {
            chatHeadFrame.origin = CGPoint(x:horizontalMargin, y:0)
            currentX = horizontalMargin + chatHeadWidth
            if isFailed {
                failedViewFrame.origin.x = currentX
                currentX += failedButtonSize.width
                currentX += horizontalInterspacing
            } else {
                failedViewFrame.origin.x = -failedButtonSize.width
            }
            bubbleViewFrame.origin.x = currentX
        } else {
            currentX = containerRect.maxX - horizontalMargin - chatHeadWidth
            chatHeadFrame.origin = CGPoint(x:currentX, y:0)
            //currentX -= horizontalInterspacing
            
            if isFailed {
                currentX -= failedButtonSize.width
                self.failedViewFrame.origin.x = currentX
                currentX -= horizontalInterspacing
            } else {
                self.failedViewFrame.origin.x = containerRect.width - -failedButtonSize.width
            }
            currentX -= bubbleSize.width
            self.bubbleViewFrame.origin.x = currentX
        }
        
        self.size = containerRect.size
        self.preferredMaxWidthForBubble = preferredWidthForBubble
    }
}
