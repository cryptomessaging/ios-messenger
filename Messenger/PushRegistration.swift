//
//  PushRegistration.swift
//  Messenger
//
//  Created by Mike Prince on 3/20/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation
import UserNotifications

class PushRegistration: NSObject {
    static let DEBUG = false
    static let instance = PushRegistration()
    
    private(set) var currentDeviceToken:String?
    
    fileprivate override init() {
    }
    
    func register() {
        if PushRegistration.DEBUG { print( "PushRegistration.register()" ) }
        
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options:[.badge, .alert, .sound]) { (granted, error) in
                // Enable or disable features based on authorization.
            }
        } else {
            let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
        }
        
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func registerDeviceToken( deviceToken:Data) {
        //let s = "\(deviceToken)"
        let token = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        //let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        if PushRegistration.DEBUG { print( "PushRegistration.registerDeviceToken(\(token))" ) }

        // remove all non-hex characters (leading <, trailing >, and spaces)
        var hex = ""
        for c in token.characters {
            if( c != "<" && c != ">" && c != " " ) {
                hex += String(c)
            }
        }
        
        currentDeviceToken = hex
        if MyUserDefaults.instance.getAccessKey() != nil {
            MobidoRestClient.instance.registerApnToken( hex ) {
                result in
                if let failure = result.failure {
                    ProblemHelper.showProblem(nil, title:"Failed to register APN token with Mobido servers".localized, failure: failure )
                }
            }
        }
    }
    
    func onDidFailToRegisterForRemoteNotificationsWithError( _ error:Error ) {
        let failure = Failure( message: error.localizedDescription )
        print( "ERROR: onDidFailToRegisterForRemoteNotificationsWithError(\(String(describing: failure.message)))" )
        ProblemHelper.showProblem(nil, title:"Failed to register APN token with Apple".localized, failure: failure )
    }
}
