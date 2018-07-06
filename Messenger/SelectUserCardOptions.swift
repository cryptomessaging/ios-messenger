import Foundation
import ObjectMapper

class SelectUserCardOptions: Mappable {
    
    var title:String?
    
    required init?(map: Map) {
    }
    
    required init() {}
    
    func mapping(map: Map) {
        title <- map["title"]
    }
}
