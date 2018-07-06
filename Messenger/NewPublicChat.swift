import Foundation
import ObjectMapper

// for creating a chat with public cards.  Allcids can only be me, or bots/public cards
class NewPublicChat: Mappable {
    var cid:String?
    var hostcids:[String]?
    var allcids:[String]?
    var subject:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        cid <- map["cid"]
        hostcids <- map["hostcids"]
        allcids <- map["allcids"]
        subject <- map["subject"]
    }
}
