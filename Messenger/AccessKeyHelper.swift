//
//  AccessKeyHelper.swift
//  Messenger
//
//  Created by Mike Prince on 1/20/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class AccessKeyHelper {
    class func checkPIIFilter() -> Bool {
        if let ak = MyUserDefaults.instance.getAccessKey(), let acm = ak.acm {
            return acm["pii"] == "filter"
        } else {
            return false
        }
    }
}
