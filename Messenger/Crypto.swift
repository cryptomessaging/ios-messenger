import Foundation
import ObjectMapper

class Crypto: Mappable {
    
    struct Types {
        static let MODP14 = "modp14"
        static let MODP15 = "modp15"
        static let MODP16 = "modp16"
    }
    
    var id: String?
    var type: String?
    var values: [String]?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        id <- map["id"]
        type <- map["type"]
        values <- map["values"]
    }
}
