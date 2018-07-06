import Foundation
import ObjectMapper

class ScreenOptions: Mappable {

    var header_background:UInt?
    var header_tint:UInt?
    
    required init?(map: Map) {
    }
    
    required init() {}
    
    func mapping(map: Map) {
        header_background <- map["header_background"]
        header_tint <- map["header_tint"]
    }
}
