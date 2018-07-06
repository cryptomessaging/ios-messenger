import Foundation
import ObjectMapper

class Failure: Mappable, CustomStringConvertible {
    var statusCode:Int?         // HTTP status code, useful for logging
    var message:String?
    var details:[String]?
    
    init(message:String) {
        self.message = message
    }
    
    init(message:String,details:[String]) {
        self.message = message
        self.details = details
    }
    
    init(statusCode:Int,message:String) {
        self.statusCode = statusCode
        self.message = message
    }
    
    init(statusCode:Int,message:String,details:[String]) {
        self.statusCode = statusCode
        self.message = message
        self.details = details
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        statusCode <- map["statusCode"]
        message <- map["message"]
        details <- map["details"]
    }
    
    var description: String {
        return self.toJSONString() ?? "(no JSON)"
    }
}
