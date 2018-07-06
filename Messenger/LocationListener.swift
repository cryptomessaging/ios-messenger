//
//  LocationListener.swift
//  Messenger
//
//  Created by Mike Prince on 4/11/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation
import ObjectMapper
import CoreLocation

// encapsulate the callback so the ScriptMessageHandler can be dereferenced when the webview/widget
// is removed from the UI, and the location updates will continue to be handled
class LocationListener: Mappable {
    
    fileprivate(set) var title:String?   // human readable description
    fileprivate(set) var key:String?
    var broadcastOnce = false;
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    init( key:String ) {
        self.key = key
    }
    
    func mapping(map: Map) {
        title <- map["title"]
        key <- map["key"]
        broadcastOnce <- map["broadcastOnce"]
    }
    
    func name() -> String {
        return title ?? "?"
    }
    
    // if the app is in the background, this does not update the webview
    // this method MUST call the completion handler when it is done, so the background task
    // can be released
    func onLocationUpdate( _ location:CLLocation, expires:Int, completion:@escaping () -> Void ) {
        guard let key = key else {
            completion()
            return
        }
        
        let info = ["key":key, "lat":"\(location.coordinate.latitude)", "lng":"\(location.coordinate.longitude)"]
        NotificationHelper.signal(.locationUpdate, info: info)
        
        guard let client = GeneralCache.instance.loadBotRestClient( key ) else {
            DebugLogger.instance.append( "WARNING: No bot rest client for location updates!" )
            completion()
            return
        }
        
        // send updates to bot server?
        // this might resend them as message.meta updates to everyone in this thread
        if broadcastOnce || expires > 0 {
            DebugLogger.instance.append( function:"SMH.onLocationUpdate()", message:"Sending to bot server" )
            let geoloc = Geoloc( location: location ).toJSONString()!
            client.httpString("POST", path: "geoloc", secure: true, content: geoloc, contentType: "application/json" ) {
                failure, result in
                
                if let failure = failure {
                    DebugLogger.instance.append( function:"onLocationUpdate()", message:"Bot server location update failed \(String(describing: failure.toJSONString()))")
                } else {
                    AnalyticsHelper.trackActivity(.locationPinged, value:client.botcid)
                }
                
                completion()
            }
            
            broadcastOnce = false   // dont do it again, until asked...
        } else {
            completion()
        }
    }
}
