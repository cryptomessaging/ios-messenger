//
//  AnalyticsHelper.swift
//  Messenger
//
//  Created by Mike Prince on 6/17/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import Foundation
import Firebase

class AnalyticsHelper {
    
    static let DEBUG = false
    
    enum Screen: String {
        case welcome
        case login
        case passwordRecovery
        case signup
        case quickstart
        case debugLog
        case addLogin
        
        case more
        case advancedSettings
        case changeTheme
        case changeSoundSetting
        case updateLogin
        case faq
        case brandIntro
        case aboutHomepage
        case homepageBotPicker
        case termsOfService
        case informationPractices
        case about
        case changePassword
        case listLogins
        case whichMe
        
        case homeBot
        
        case askBirthday
        case directNoticeForm
        case directNoticeSent
        
        case startConsent
        case scanConsent
        case consentFinished
        case kidList
        case kidDetail
        case consentStatus
        
        case addToChat
        case chatHistory
        case createChat
        case chat

        case flagChat
        case flagCard
        case flagMessage
        case InvitePeople   // informational dialog asking yes/no
        case sharingInvite  // handed off to iOS which shows ways of sharing the invite
                            // track this as an optimistic view so it can be in a funnel
        //case ChatOptions
        
        case myCards
        case createCard
        case editCard

        case selectMyCard
        case cardDetail
        
        case fullWidget // full screen of widget
    }
    
    class func trackScreen(_ name:Screen, vc:UIViewController ) {
        /*let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: name.rawValue)
        
        let builder = GAIDictionaryBuilder.createScreenView()
        tracker?.send(builder?.build() as [NSObject:AnyObject]!)
         */
        //Analytics.logEvent(<#T##name: String##String#>, parameters: <#T##[String : Any]?#>)
        Analytics.setScreenName( name.rawValue, screenClass: String( describing:vc) )
        if DEBUG { print( "trackScreen \(name.rawValue)" ) }
    }
    
    enum Popover: String {
        case cardAdvancedOptions
        case widgetOptions
        case problem    // problem dialog showing
        case joinChat       // use RSVP to join chat
    }
    
    class func trackPopover(_ name:Popover, vc:UIViewController ) {
        /*let tracker = GAI.sharedInstance().defaultTracker
         tracker?.set(kGAIScreenName, value: name.rawValue)
         
         let builder = GAIDictionaryBuilder.createScreenView()
         tracker?.send(builder?.build() as [NSObject:AnyObject]!)
         */
        //Analytics.logEvent(<#T##name: String##String#>, parameters: <#T##[String : Any]?#>)
        //Analytics.setScreenName( name.rawValue, screenClass: String( describing:vc) )
        Analytics.logEvent( "popover", parameters: [ AnalyticsParameterItemName: name.rawValue as NSObject ] )
    }
    
    //
    // Track user actions, usually clicking on buttons or links
    //
    
    enum Action: String {
        case tappedRecommendedBot
        case logout
        case reviewAccount
    }
    
    class func trackAction( _ name:Action ) {
        Analytics.logEvent( "user_action", parameters: [ AnalyticsParameterItemName: name.rawValue as NSObject ] )
    }
    
    class func trackAction( _ name:Action, value:String ) {
        Analytics.logEvent( "user_action", parameters: [ AnalyticsParameterItemName: name.rawValue as NSObject, AnalyticsParameterValue: value as NSObject ] )
    }
    
    //
    // Results of user actions
    //
    
    // use past tense to make readable, SubjectVerb
    enum Result: String {
        
        case synced
        case passwordChanged
        
        case cardCreated
        case cardUpdated
        
        case chatCreated
        case botAdded       // Bot added to chat
        case coachAdded
        case contactsAdded
        case chatJoined     // person joined chat from RSVP
        case chatLeft       // self left chat
        case chatDeleted
        case cardRemoved    // forcefully from chat
        case chatForgotten
        case textSent       // Text message sent
        case homepageBotPicked
        
        case parentConsented
        case deniedConsent
        case denyConsentFailed
        
        case themeChanged
        case soundSettingChanged
        case loginUpdated
        
        //case reviewingAccount
        case disabledChildAccount
        case enabledChildAccount
        case deletedChildAccount
        
        case widgetLocationOn
        case widgetLocationOff
        
        case chatFlagged
        case messageFlagged
        case cardFlagged
        
        case reviewingAccount
        
        case selectUserCardCancelled    // cancelled request to select user card
    }
    
    class func trackResult(_ name:Result) {
        trackResult(name, value:nil)
    }
    
    class func trackResult(_ name:Result, value:String? ) {
        /*
        let tracker = GAI.sharedInstance().defaultTracker
        
        let builder = GAIDictionaryBuilder.createEvent(withCategory: "Result", action: name.rawValue, label:value, value:nil)
        tracker?.send(builder?.build() as [NSObject:AnyObject]!)
         */
        
        if let value = value {
            Analytics.logEvent( "action_result", parameters: [ AnalyticsParameterItemName: name.rawValue as NSObject, AnalyticsParameterValue: value as NSObject ] )
        } else {
            Analytics.logEvent( "action_result", parameters: [ AnalyticsParameterItemName: name.rawValue as NSObject ] )
        }
    }
    
    //
    // Activities which are started automatically, or by bots in widgets
    //
    
    // use past tense to make readable, SubjectVerb
    enum Activity: String {
        case selectUserCard
        case locationPinged
        
        case updateBotServer
        case queryBotServer
        
        case widgetFreeBusyDip      // widget asked calendar for update
        //case widgetUpdated        // widget sent post/put/delete to bot server
        
        case loggingOut             // can be user initiated, or caused by auth failure on HTTP request
    }
    
    class func trackActivity(_ name:Activity) {
        trackActivity(name, value:nil)
    }
    
    class func trackActivity(_ name:Activity, value:String?) {
        /*
        let tracker = GAI.sharedInstance().defaultTracker
        
        let builder = GAIDictionaryBuilder.createEvent(withCategory: "Action", action: name.rawValue, label:value, value:nil)
        tracker?.send(builder?.build() as [NSObject:AnyObject]!)
         */
        if let value = value {
            Analytics.logEvent( "activity", parameters: [ AnalyticsParameterItemName: name.rawValue as NSObject, AnalyticsParameterValue: value as NSObject ] )
        } else {
            Analytics.logEvent( "activity", parameters: [ AnalyticsParameterItemName: name.rawValue as NSObject ] )
        }
    }
    
    class func trackActivity(_ name:Activity, source:String, value:String) {

        Analytics.logEvent( "activity", parameters: [
            AnalyticsParameterItemName: name.rawValue as NSObject,
            AnalyticsParameterSource: source as NSObject,
            AnalyticsParameterValue: value as NSObject,
            ] )
    }
    
    //
    // Track presense of visible screen elements
    //
    
    enum ScreenElement: String {
        case widget
    }
    
    class func trackScreenElement( _ name:ScreenElement, value:String ) {
        Analytics.logEvent( "screen_element", parameters: [ AnalyticsParameterItemName: name.rawValue as NSObject, AnalyticsParameterValue: value as NSObject ] )
    }
}
