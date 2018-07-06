import Foundation
import ObjectMapper

class Reputation: Mappable {
    
    var name:String?
    var label:String?
    var icon:String?
    var certs:[String]?
    var type:String?
    var value:String?
    var flags:Int?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        name <- map["name"]
        label <- map["label"]
        icon <- map["icon"]
        certs <- map["certs"]
        type <- map["type"]
        value <- map["value"]
        flags <- map["flags"]
    }
}
