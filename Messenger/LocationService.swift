import Foundation
import CoreLocation
import ObjectMapper

class ListenerEntry: Mappable {
    var expires:Int = 0 // SECONDS since epoch, 0 = already expired.  ObjectMapper doesn't like Int64 so millis are out :(
    var listener:LocationListener!
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        expires <- map["expires"]
        listener <- map["listener"]
    }
    
    init( listener:LocationListener ) {
        self.listener = listener
    }
    
    func updateExpires( _ minutes:Int ) {
        let newExpires = TimeHelper.getSeconds() + minutes * 60
        if newExpires > expires {
            self.expires = newExpires
        }
    }
}

class LocationService: LocationTrackerDelegate {
    
    static let instance = LocationService()
    
    fileprivate let locationTracker = LocationTracker()
    fileprivate var updateListeners:[String:ListenerEntry] = [:]    // may hold entries for widgets not on screen anymore

    init() {
        //super.init()
        
        locationTracker.delegate = self
        
        // Rebuild updateListener list from disk cache
        if let listeners = GeneralCache.instance.loadLocationListeners() {
            if LocationService.isDebuggingLocation() {
                DebugLogger.instance.append( "Restoring location listeners..." )
            }
            let now = TimeHelper.getSeconds()
            for e in listeners {
                if e.expires > now || e.expires == 0 {  // expires = 0 for fire once locations
                    if let key = e.listener.key {
                        updateListeners[key] = e
                    }
                }
            }
            
            if !updateListeners.isEmpty {
                locationTracker.start()
            }
        }
    }
    
    /* call when app is closing/going into background
    // NOTE does NOT stop location services, so we can keep getting them even when app is backgrounded
    func close() {
        //save()
    }*/
    
    // typically used when logging out
    func clear() {
        UIHelper.onMainThread {
            self.locationTracker.stop()
            self.updateListeners.removeAll()
            self.save();
        }
    }
    
    //
    // Functions to manage location fetching exposed to bot widget
    //
    
    // get location once, returns nil if locations could be requested
    func fetchLocation( _ listener:LocationListener ) {
        if LocationService.isDebuggingLocation() {
            DebugLogger.instance.append( "Fetching location once for \(String(describing: listener.key))" )
        }
        
        registerListener( listener ) {
            failure in
            
            if let failure = failure {
                let key = listener.key == nil ? "<missing>" : listener.key!
                let info = ["key":key, "failureMessage":"\(failure.message!)" ]
                NotificationHelper.signal(.locationFailure, info: info)
            } else {
                // no expires means do it once
                self.locationTracker.start()
            }
        }
    }
    
    // For the next N minutes, get location ~once a minute
    func requestLocationUpdates( _ listener:LocationListener, minutes:Int ) {
        UIHelper.onMainThread {
            guard let key = listener.key else {
                DebugLogger.instance.append( "ERROR: LocationListener.requestLocationUpdates() missing key \(listener)" )
                return
            }
            
            if let e = self.updateListeners[ key ] {
                e.updateExpires(minutes)
            } else {
                let e = ListenerEntry(listener: listener)
                e.updateExpires(minutes)
                self.updateListeners[ key ] = e
            }
            
            // make sure we are requesting location
            if LocationService.isDebuggingLocation() {
                DebugLogger.instance.append( "Fetching location for \(minutes)min for \(key)" )
            }
            
            self.save()
            self.locationTracker.start()
        }
    }
    
    // cancels ALL location updates for this tid/mycid/botcid listener
    func cancelLocationUpdates(_ listener:LocationListener ) {
        UIHelper.onMainThread {
            guard let key = listener.key else {
                DebugLogger.instance.append( "ERROR: LocationListener.cancelLocationUpdates() missing key \(listener)" )
                return
            }
            
            self.updateListeners.removeValue(forKey: key)
            self.save()
            
            // if there are no more listeners, stop asking for locations
            if( self.updateListeners.count == 0 ) {
                self.locationTracker.stop();
            }
        }
    }
    
    //
    // Wiring into script message handler
    //
    
    // this might replace an old one (widget was closed, and a new copy is opening for the same bot),
    // so make sure to preserve expiration
    func registerListener( _ listener:LocationListener, requirePrevious:Bool = false, completion:((Failure?)->Void)? ){
        UIHelper.onMainThread {
            guard let key = listener.key else {
                DebugLogger.instance.append( "ERROR: LocationListener.registerListener() missing key \(listener)" )
                completion?( Failure(message: "LocationListener.registerListener missing key" ) )
                return
            }
            
            if self.updateListeners[key] == nil && requirePrevious {
                completion?( Failure(message: "LocationListener.registerListener missing required previous listener" ) )
                return
            }
            
            let e = ListenerEntry(listener: listener)
            if let expires = self.updateListeners[key]?.expires {
                e.expires = expires
                self.locationTracker.start()
            }
            self.updateListeners[key] = e
            
            self.save()
            completion?(nil)
        }
    }
    
    //
    // Utility
    //
    
    // always start a background task so any long running HTTP requests can finish
    func onLocationChange( _ location:CLLocation ) {
        let isDebugging = LocationService.isDebuggingLocation()
        UIHelper.onMainThread {
            // quick sanity check
            if self.updateListeners.isEmpty {
                if isDebugging {
                    DebugLogger.instance.append( "Ignoring location with no listeners" )
                }
                return
            }
            
            if isDebugging {
                DebugLogger.instance.append( "onLocationChange() to \(location)" )
            }
            
            let start = TimeHelper.getSeconds() // track how long we took
            var runningUpdates:Int32 = 1
            let app = UIApplication.shared
            let taskid = app.beginBackgroundTask (expirationHandler: {
                // this completion handler is only called when started from the background
                
                if runningUpdates > 0 && isDebugging {
                    DebugLogger.instance.append( "ERROR: background task ended while \(runningUpdates) updates are still running")
                }
                
                let duration = TimeHelper.getSeconds() - start
                if isDebugging {
                    DebugLogger.instance.append( "Finished updating location listeners in \(duration) seconds" )
                }
            })
            
            let now = start     // for readability
            var removeKeys = [String]()
            for (key,e) in self.updateListeners {
                if isDebugging {
                    DebugLogger.instance.append( "Sending location update to \(key)" )
                }
                OSAtomicIncrement32(&runningUpdates)
                e.listener.onLocationUpdate( location, expires: e.expires ) {
                    if OSAtomicDecrement32(&runningUpdates) == 0 {
                        app.endBackgroundTask(taskid)
                    }
                }
                
                if e.expires < now {
                    // listener was one time (expires=0) or has expired, so remove
                    if isDebugging {
                        DebugLogger.instance.append( "removing expired listener \(key)" )
                    }
                    removeKeys.append( key )
                }
            }
            
            // anything need to be removed?
            for key in removeKeys {
                self.updateListeners.removeValue(forKey: key)
            }
            if !removeKeys.isEmpty {
                self.save()
            }
            
            if self.updateListeners.isEmpty {
                self.locationTracker.stop()
            }
            
            if OSAtomicDecrement32(&runningUpdates) == 0 {
                app.endBackgroundTask(taskid)
            }
        }
    }
    
    fileprivate func save() {
        let entries = Array(updateListeners.values)
        GeneralCache.instance.saveLocationListeners(entries)
    }
    
    class func isDebuggingLocation() -> Bool {
        return MyUserDefaults.instance.check(.IsLocationDeveloper)
    }
}
