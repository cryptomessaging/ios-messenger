import Foundation
import ObjectMapper

class OptionItem: Mappable {
    var id:String?
    var label:String?
    var url:String?
    
    required init?(map: Map) {
    }
    
    required init() {}
    
    func mapping(map: Map) {
        id <- map["id"]
        label <- map["label"]
        url <- map["url"]
    }
}
