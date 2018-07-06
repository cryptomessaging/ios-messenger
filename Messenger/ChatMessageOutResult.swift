import Foundation
import ObjectMapper

class ChatMessageOutResult: BaseResult {
    var created:String?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        created <- map["created"]
    }
}
