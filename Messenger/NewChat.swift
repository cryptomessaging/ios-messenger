import Foundation
import ObjectMapper

class NewChat: Mappable {
    var subject:String?
    var mycid:String?
    var contacts:[ChatContact]?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        subject <- map["subject"]
        mycid <- map["mycid"]
        contacts <- map["contacts"]
    }
}
