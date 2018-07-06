import Foundation
import ObjectMapper

class AddContacts: Mappable {
    
    var mycid:String?
    var contacts:[ChatContact]?

    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        mycid <- map["mycid"]
        contacts <- map["contacts"]
    }
}
