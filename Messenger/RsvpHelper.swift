import UIKit


class RsvpPopoverDelegate : NSObject, UIPopoverPresentationControllerDelegate {
    
}

class RsvpHelper {
    
    class func showRsvpDialog(_ vc:UIViewController, secret:String ) {
        
        MyCardsModel.instance.loadWithProblemReporting(.local, statusCallback:nil) {
            success in
            
            if success == false {
                // error already reported
                return
            } else if MyCardsModel.instance.cards.isEmpty {
                AlertHelper.showAlert(vc, title: "Please create a card first".localized, message: "You need a card to represent you before you can join any chats".localized, okStyle: .default ) {
                    // they clicked ok, so let them create a card
                    EditCardViewController.showCreateCard(vc) {
                        card in
                        RsvpHelper.showRsvpDialog2(vc, secret:secret )
                    }
                }
            } else {
                RsvpHelper.showRsvpDialog2(vc, secret:secret )
            }
        }
    }
    
    class func showRsvpDialog2(_ vc:UIViewController, secret:String ) {
        // get information about the RSVP
        MobidoRestClient.instance.fetchRsvpPreview(secret) {
            preview in
            
            if let failure = preview.failure {
                ProblemHelper.showProblem(vc, title:"Problem fetching RSVP information".localized, failure: failure )
            } else {
                DispatchQueue.main.async(execute: {
                    JoinThreadViewController.showJoinThreadPopover(vc, rsvpPreview:preview )
                })
            }
        }
    }
    
    class func acceptRsvp( _ secret:String, mycid:String, completion:@escaping (Bool) -> Void ) {
        MobidoRestClient.instance.claimRsvpOffer(secret, mycid:mycid ) {
            result in
            handleRsvpClaim( secret, mycid:mycid, claim:result,retry:0, completion:completion)
        }
    }
    
    class func handleRsvpClaim( _ secret:String, mycid:String, claim:RsvpClaimResult, retry:Int, completion:@escaping (Bool) -> Void ) {
        if let failure = claim.failure {
            ProblemHelper.showProblem(nil, title:"Failed to accept RSVP".localized, failure: failure )
            completion(false)
        } else if claim.cutoff != nil {
            ProblemHelper.showProblem(nil, title:"RSVP maxed out".localized, message: "All the spots have been taken.".localized)
            MyUserDefaults.instance.set(.PENDING_RSVP_SECRET, withValue:nil)
            completion(false)
        } else if let holdoff = claim.holdoff {
            // too many times?
            if retry > 3 {
                let message = String( format:"We tried the server %d time with no success".localized, retry )
                ProblemHelper.showProblem(nil, title:"Too many attempts".localized, message: message)
                completion(false)
            } else {
                // we need to wait a little bit, and then see if we got it
                let delay = Int64(holdoff) * Int64(NSEC_PER_SEC)
                let time = DispatchTime.now() + Double(delay) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: time) {
                    MobidoRestClient.instance.applyRsvpOffer(secret, mycid: mycid ) {
                        result in
                        handleRsvpClaim(secret, mycid:mycid, claim:result, retry:retry + 1, completion:completion)
                    }
                }
            }
        } else {
            // Success!
            MyUserDefaults.instance.set(.PENDING_RSVP_SECRET, withValue:nil)
            
            // a new push message is on its way... we could just exit, but there will be a weird gap 
            // SOOOOO... update our local database
            if let thread = claim.thread, let tid = thread.tid {
                ChatDatabase.instance.addThread(thread)
                NotificationHelper.signalShowChat(tid)
            }

            completion(true)
        }
    }
}
