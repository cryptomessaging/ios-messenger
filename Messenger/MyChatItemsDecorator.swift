import Foundation
import Chatto
//import ChattoAdditions

class MyChatItemsDecorator: ChatItemsDecoratorProtocol {
 
    func decorateItems( _ chatItems: [ChatItemProtocol]) -> [DecoratedChatItem] {
        var result = [DecoratedChatItem]()
        for item in chatItems {
            let attr = ChatItemDecorationAttributes( bottomMargin: 5, showsTail: true)
            result.append( DecoratedChatItem(chatItem: item, decorationAttributes:attr ) )
        }
        
        return result
    }
}
