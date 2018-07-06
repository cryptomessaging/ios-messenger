import Foundation
import ObjectMapper

class WidgetEnvironment: Mappable {
    var version:String?
    var debug:Bool?
    var tz:String?
    var theme:String?
    var fullscreen:Bool?
    
    required init?(map: Map) {
    }
    
    required init() {}
    
    func mapping(map: Map) {
        version <- map["version"]
        debug <- map["debug"]
        tz <- map["tz"]
        theme <- map["theme"]
        fullscreen <- map["fullscreen"]
    }
}
