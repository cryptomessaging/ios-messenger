//
//  LatestChatMessage.swift
//  Messenger
//
//  Created by Mike Prince on 1/7/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import Foundation
import ObjectMapper

class LatestChatMessage: Mappable {
    var created:String?  // ISO8601
    var cid:String?
    var body:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        created <- map["created"]
        cid <- map["cid"]
        body <- map["body"]
    }
    
    class func isEqual(_ m1:LatestChatMessage?, m2:LatestChatMessage? ) -> Bool {
        if m1 == nil && m2 == nil {
            return true
        } else if let t1 = m1, let t2 = m2 {
            return StringHelper.isEqual(t1.created, s2:t2.created) &&
                StringHelper.isEqual(t1.cid, s2:t2.cid) &&
                StringHelper.isEqual(t1.body, s2:t2.body)
        } else if m1 != nil {
            // implies m2 is nil
            return isEmpty( m1! )
        } else {
            return isEmpty( m2! )
        }
    }
    
    class func isEmpty(_ msg:LatestChatMessage?) -> Bool {
        if let m = msg {
            return m.created == nil && m.cid == nil && m.body == nil
        } else {
            return true
        }
    }
}
