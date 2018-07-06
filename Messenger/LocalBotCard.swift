import Foundation
import ObjectMapper

class LocalBotCard: Card {
    var icon:UIImage?
    
    init(name:String, icon:UIImage) {
        super.init()
        self.nickname = name
        self.icon = icon
    }

    required init?(map: Map) {
        super.init(map:map)
    }
}
