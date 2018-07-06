//
//  BaseResult.swift
//  Messenger
//
//  Created by Mike Prince on 12/1/15.
//  Copyright © 2015 Mike Prince. All rights reserved.
//

import Foundation
import ObjectMapper

class BaseResult: Mappable {
    var failure:Failure?
    
    init(failure:Failure) {
        self.failure = failure
    }
    
    required init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        failure <- map["failure"]
    }
    
    func isFailure() -> Bool {
        return failure != nil
    }
}
