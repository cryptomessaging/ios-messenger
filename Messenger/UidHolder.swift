import Foundation
import ObjectMapper

class UidHolder: Mappable {
    var uid:String?
    
    init() {
    }
    
    init( uid:String? ) {
        self.uid = uid
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        uid <- map["uid"]
    }
}
