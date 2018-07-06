//
//  QuickstartHelper.swift
//  Messenger
//
//  Created by Mike Prince on 3/10/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class QuickstartHelper {
    
    class func createAnonymousAccount( _ vc:UIViewController ) {
        createAccessKey(vc) {
            progress in
            
            if let progress = progress {
                progress.stop()
                MainViewController.showMain()
            }
        }
    }
    
    class func createAccessKey( _ vc:UIViewController, completion:@escaping (ProgressIndicator?)->Void ) {
        let progress = ProgressIndicator(parent: vc.view, message: "Quickstarting (Progress)".localized )
        MobidoRestClient.instance.createAccessKey(Login(authority: "anon")) {
            result in
            
            if ProblemHelper.showProblem(vc, title: "Problem creating account (Alert Title)".localized, failure: result.failure ) {
                progress.stop()
                completion(nil)
                return
            }
            
            // save our access key
            let prefs = MyUserDefaults.instance
            prefs.setAccessKey( result.accessKey )
            
            // register APN token with new account if available
            guard let token = PushRegistration.instance.currentDeviceToken else {
                // no APN token, so skip to next step...
                completion( progress )
                return
            }
            
            MobidoRestClient.instance.registerApnToken( token ) {
                result in
                
                if ProblemHelper.showProblem(vc, title: "Problem registering APN token (Alert Title)".localized, failure: result.failure ) {
                    progress.stop()
                    completion(nil)
                } else {
                    completion( progress )
                }
            }
        }
    }
    
    /*
    class func startCoachChat( _ vc:UIViewController, progress:ProgressIndicator, completion:@escaping (ProgressIndicator?)->Void ) {
        CoachCardsModel.instance.fetchCardIds {
            cids in
            
            if cids.count == 0 {
                // failed to find cids, so just wrap up
                completion( progress )
                return
            }
            
            // create new chat with random coach
            let newChat = NewChat()
            newChat.subject = "Welcome Coach"
            newChat.cid = result.cid    // my cid
            //newChat.allcids = [ result.cid!, self.sunriseBot!.cid!, self.payBot!.cid! ]
            newChat.allcids = [String]( arrayLiteral: result.cid! )
            newChat.allcids?.append( contentsOf: botCids )
            
            MobidoRestClient.instance.createChat(newChat) {
            
            
        }
    }*/
}
