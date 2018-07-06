//
//  RecentChatContactsFinder.swift
//  Messenger
//
//  Created by Mike Prince on 3/23/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class RecentChatContactsFinder {
    
    class func findContacts( _ mycid:String, _ completion:(_ closeContacts:[ChatContact],_ allContacts:[ChatContact])->Void ) {
        var closeContacts = [ChatContact]()
        var allContacts = [ChatContact]()

        let mycids = MyCardsModel.instance.cardIds
        
        for t in ThreadHistoryModel.instance.threads {
            if let cids = StringHelper.asArray(t.cids) {
                // is mycid in this chat?
                let imInChat = cids.index(of:mycid) != nil

                for cid in cids {
                    // one of my cards?
                    if mycids.contains(cid) != true {
                        if imInChat {
                            add( cid, tid:t.tid!, list:&closeContacts )
                        }
                        
                        // always all to all contacts
                        add( cid, tid:t.tid!, list:&allContacts )
                    }
                }
            }
        }
        
        completion(closeContacts,allContacts)
    }
    
    class func add( _ cid:String, tid:String, list:inout [ChatContact] ) {
        if let i = list.index(where:{$0.cid == cid}) {
            list[i].tids!.append( tid )
        } else {
            let contact = ChatContact()
            contact.cid = cid
            contact.tids = [tid]
            list.append( contact )
        }
        
    }
}
