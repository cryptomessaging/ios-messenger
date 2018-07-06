//
//  ExclusiveChatHelper.swift
//  Messenger
//
//  Created by Mike Prince on 7/18/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class ExclusiveChatHelper {
    
    class func ensureExclusiveChat( parent:UIView, mycard:Card, peer:Card, subject:String?,
                                    completion:@escaping( _ failure:Failure?, _ thread:ChatThread?) -> Void ) {
        
        guard let mycid = mycard.cid, let peercid = peer.cid else {
            completion( Failure( message:"Missing persona id (Error)".localized ), nil )
            return
        }
        
        // do we already have a chat going with just me and this bot?
        let threadHistory = ThreadHistoryModel.instance
        for thread in threadHistory.threads {
            if let cids = StringHelper.asArray(thread.cids) { // convert csv to array of strings
                if cids.count == 2 { // assumption is one cid is mine, and one is bots = 2 cids
                    let peerindex = cids.index(of:peercid)
                    if peerindex != nil { // found the peer cid?
                        let othercid = peerindex == 0 ? cids[1] : cids[0]
                        if othercid == mycid {
                            // whew! that was a lot of conditions!
                            completion( nil, ChatThread( cached:thread ) )
                            return
                        }
                    }
                }
            }
        }
        
        let progress = ProgressIndicator(parent:parent, message:"Creating Chat (Progress)".localized)
        let allcids = [ mycid, peercid ]
        ThreadHelper.createPublicChat(hostcid: mycid, allcids: allcids, subject:subject ) {
            failure, thread in
            
            progress.stop()
            completion( failure, thread )
        }
    }
}
