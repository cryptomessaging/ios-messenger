import Foundation
import ObjectMapper

class NewRsvp: Mappable {
    var expires:Int?
    var keys:[String:String]?
    var max:Int?    // number of people to let in, 0=unlimited
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        expires <- map["expires"]
        keys <- map["keys"]
        max <- map["max"]
    }
}

