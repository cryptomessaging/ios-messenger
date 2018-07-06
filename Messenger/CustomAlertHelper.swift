//
//  CustomAlertHelper.swift
//  Messenger
//
//  Created by Mike Prince on 11/29/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import Foundation
import AVFoundation

class CustomAlertHelper {
    
    static let DEBUG = false
    
    class func ensureCustomAlertSound( _ soundUrl:URL, completion:@escaping (_ usedNetwork:Bool,_ soundpath:String?)->() ) {
        let libpath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        guard let host = soundUrl.host else {
            completion(false,nil)
            return
        }
        var pathComponents = soundUrl.pathComponents
        
        let filename = pathComponents.last!
        pathComponents.removeFirst()    // leading '/'
        pathComponents.removeLast()     // actual filename
        let path = pathComponents.count == 0 ? "" : "/" + pathComponents.joined(separator: "/")
        
        let dir = "\(libpath)/Sounds/\(host)\(path)"
        let fullpath = "\(dir)/\(filename)"
        
        // is file already in ~/Libary/Sounds?
        if FileManager.default.fileExists(atPath: fullpath) {
            completion(false,fullpath)
            return
        }
        
        // fetch sound and put in ~/Library/Sounds
        HttpClient.fetch( soundUrl, onSuccess: {
            data in
            
            do {
                // make sure directory exists
                if !FileManager.default.fileExists(atPath: dir) {
                    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
                }

                try? data.write(to: URL(fileURLWithPath: fullpath), options: [.atomic])
                DebugLogger.instance.append( "SUCCESS: saved custom sound of \(data.count) bytes to \(fullpath)" )
            } catch {
                DebugLogger.instance.append( "FAILURE: ensureCustomAlertSound() \(error)" )
            }
            
            completion(true,fullpath)
        }, onFailure: {
            failure in
            
            DebugLogger.instance.append( "FAILURE: ensureCustomAlertSound() \(String(describing: failure.message))" )
            completion(true,nil)
        })
    }
    
    class func playSound( _ fullpath:String ) {
        let url = URL( fileURLWithPath: fullpath )
        do {
            // AVAudioSessionCategorySoloAmbient respects mute switch
            let category = SoundHelper.isAlwaysOn() ? AVAudioSessionCategoryPlayback : AVAudioSessionCategorySoloAmbient
            try AVAudioSession.sharedInstance().setCategory(category)
            try AVAudioSession.sharedInstance().setActive(true)
            
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            
            UIHelper.delay(15) {    // TODO hold for 30s? that's the max iOS allows to notifications
                print( "Waited, and now \(player.isPlaying)" )
            }
        } catch {
            DebugLogger.instance.append( "FAILURE: playSound() \(error)" )
        }
    }
    
    /*
    class func fireLocalNotification( alertBody:String?, tid:String?, localSound:String ) {
        if tid == nil || alertBody == nil {
            print( "Funny - no alertBody or tid for custom alert sound" );
            return;
        }
        
        let notification = UILocalNotification()
        notification.alertBody = alertBody! + "2"
        // notification.soundName = localSound
        notification.userInfo = ["tid": tid! ]
        
        UIApplication.sharedApplication().scheduleLocalNotification(notification)
        DebugLogger.instance.append( "SENT second notification!" )
    }*/
}
