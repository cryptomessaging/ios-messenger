import Foundation
import ObjectMapper

class Media: Mappable {
    var type:String?    // "image/jpeg;base64" OR "image/jpeg", same as HTTP content-type
    var src:String?     // default is url, OR base64 jpeg on incoming messages with "image/jpeg;base64"
    var meta:[String:String]?   // JSON encoded meta info, hints, specific to type
                                   // i.e. for JPEG width: <float>, height: <float>
    
    init() {
    }
    
    init( type:String, src:String?, meta:[String:String]? ) {
        self.type = type
        self.src = src
        self.meta = meta
    }
    
    var hashValue: Int {
        get {
            return (type == nil ? 0 : type!.hashValue) ^ (src == nil ? 0 : src!.hashValue) ^ metaHash()
        }
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        type <- map["type"]
        src <- map["src"]
        meta <- map["meta"]
    }
    
    func metaFloat(key:String) -> Float? {
        if let meta = self.meta, let value = meta[key] {
            return (value as NSString).floatValue
        } else {
            return nil
        }
    }
    
    func metaHash() -> Int {
        var result = 0
        if let meta = meta {
            for e in meta {
                result ^= e.key.hashValue ^ e.value.hashValue
            }
        }

        return 0
    }
}
