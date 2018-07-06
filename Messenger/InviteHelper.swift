//
//  InviteHelper.swift
//  Messenger
//
//  Created by Mike Prince on 3/23/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class InviteHelper {
    
    class func start( _ vc:UIViewController, mycid:String, thread:CachedThread, inviteButton:UIView, completion:@escaping ()->Void ) {
        let newRsvp = NewRsvp()
        newRsvp.keys = ["cid":mycid, "tid":thread.tid!]
        newRsvp.expires = Seconds.IN_ONE_HOUR * 24 * 7  // 7 days
        newRsvp.max = 5
        
        let progress = ProgressIndicator(parent: vc.view, message:"Creating link (Progress)".localized)
        MobidoRestClient.instance.createRsvp(newRsvp ) {
            result in
            
            DispatchQueue.main.async {
                progress.stop()
                
                if let failure = result.failure {
                    ProblemHelper.showProblem(vc, title: "Failed to create RSVP".localized, failure: failure) {
                        completion()
                    }
                } else {
                    self.invite(vc, result:result, thread:thread, inviteButton:inviteButton)
                    completion()
                }
            }
        }
    }
    
    // make sure this is always called from main thread
    class func invite(_ vc:UIViewController, result:CreateRsvpResult, thread:CachedThread, inviteButton:UIView ) {
        let date = TimeHelper.asDate(result.expires)
        let prettyDate = TimeHelper.asPrettyDate( date! )
        
        let host = MyUserDefaults.instance.getMobidoApiServer()
        let url = "\(host)/rsvp/\(result.secret!)"
        
        let message = String(format:"I'm planning '%@' and would like you to join the conversation.\n\nClick %@ to learn more.\n\n(This link expires %@)".localized, thread.subject!, url, prettyDate )
        let items:[String] = [message]
        
        let avc = UIActivityViewController(activityItems: items, applicationActivities: nil )
        if let ppc = avc.popoverPresentationController {
            // ipad support
            ppc.sourceView = inviteButton //     .barButtonItem = shareButton
        }
        vc.present(avc, animated:true, completion:nil )
        AnalyticsHelper.trackScreen( .sharingInvite, vc:avc )   // optimistically they will see an iOS sharing view
    }
}
