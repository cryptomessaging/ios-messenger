//
//  NicknameHelper.swift
//  Messenger
//
//  Created by Mike Prince on 2/5/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class NicknameHelper {
    // if the nickname is not valid, popover a warning
    @discardableResult class func alertIfNicknameInvalid(_ vc:UIViewController,nickname:String?,doFilterPII:Bool) -> Bool {
        if doFilterPII && StringHelper.countWords( StringHelper.clean(nickname) ) > 1 {
            AlertHelper.showOkAlert(vc, title: "Only One Word Names Allowed (Alert Title)".localized, message: "We cannot allow two word names until your parent signs the consent form".localized, okAction: nil)
            return false
        }
        
        return true
    }
    
    class func isNicknameValid(_ nickname:String?,doFilterPII:Bool) -> Bool {
        let wordcount = StringHelper.countWords( StringHelper.clean(nickname) )
        if wordcount == 0 {
            return false
        }
        
        if doFilterPII && wordcount > 1 {
            return false
        } else {
            return true
        }
    }
}
