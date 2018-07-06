import Foundation
import CoreLocation

protocol LocationTrackerDelegate: class {
    func onLocationChange( _ location:CLLocation )
}

class LocationTracker: NSObject, CLLocationManagerDelegate {
    
    fileprivate static let locationLookback:Double = 60   // consider locations up to 60 seconds old
    fileprivate static let locationFrequency:Double = 60  // allow new locations every 60 seconds
    fileprivate var askedToEnableLocationService = false
    
    enum State {
        case started
        case stopped
    }
    fileprivate var state = State.stopped
    
    fileprivate let manager = CLLocationManager()
    fileprivate var mostRecentLocation:CLLocation!
    weak var delegate:LocationTrackerDelegate?
    
    override init() {
        super.init()
        
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone   // meters of change to trigger updates; None means all updates are provided
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false  // TODO:remove, this is discouraged...
    }
    
    // this can be called many times, even when the tracker is started
    // each new call ensures the next location update is passed along immediately, and 
    // not delayed by up to a minute
    func start() {
        if LocationService.isDebuggingLocation() {
            DebugLogger.instance.append( "LocationTracker.start()" )
        }

        mostRecentLocation = nil    // Allow a new location in, otherwise it might be ignored as too new
        
        if state == .started {
            if LocationService.isDebuggingLocation() {
                DebugLogger.instance.append( "LocationTracker.start() already started" )
            }
            return
        }
        
        // authorized to use location?
        let status = CLLocationManager.authorizationStatus()
        switch( status ) {
        case CLAuthorizationStatus.notDetermined:
            DebugLogger.instance.append( "Location service not determined" )
            manager.requestAlwaysAuthorization()
        // continue anyway, its safe to start before authorization - locations just wont be delivered yet
        case CLAuthorizationStatus.restricted:
            DebugLogger.instance.append( "Location service restricted" )
            askToEnableLocationService()
            return
        case CLAuthorizationStatus.denied:
            DebugLogger.instance.append( "Location service denied" )
            askToEnableLocationService()
            return
        case CLAuthorizationStatus.authorizedAlways:
            DebugLogger.instance.append( "AuthorizedAlways" )
        case CLAuthorizationStatus.authorizedWhenInUse:
            // NOTE this path will never happen because we never asked for when-in-use permission
            DebugLogger.instance.append( "AuthorizedWhenInUse" )
            manager.requestAlwaysAuthorization()
        }
        
        if CLLocationManager.locationServicesEnabled() != true {
            // TODO popup dialog
            DebugLogger.instance.append( "LocationTracker.start() Location services disabled, please use settings to enable" )
            return
        }
        
        if LocationService.isDebuggingLocation() {
            DebugLogger.instance.append( "LocationTracker.start() started" )
        }
        manager.startUpdatingLocation()
        state = .started
    }
    
    fileprivate func askToEnableLocationService() {
        UIHelper.onMainThread {
            if self.askedToEnableLocationService {
                return
            }
            
            guard let vc = UIHelper.topVC() else {
                return
            }
            
            self.askedToEnableLocationService = true
            
            let alertVC = UIAlertController(title: "Geolocation Is Not Enabled (Title)".localized, message: "For using geolocation you need to enable it in Settings".localized, preferredStyle: .actionSheet)
            alertVC.addAction(UIAlertAction(title: "Open Settings (Button)".localized, style: .default) { value in
                let path = UIApplicationOpenSettingsURLString
                if let settingsURL = URL(string: path), UIApplication.shared.canOpenURL(settingsURL) {
                    UIApplication.shared.openURL(settingsURL)
                }
            })
            let center = vc.view.frame.bma_center
            UIHelper.ipadFixup(alertVC, atLocation:center, inView:vc.view)
            vc.present(alertVC, animated: true, completion: nil)
        }
    }
    
    // Also used by logout helper to hard stop all location activities
    func stop() {
        if state == .stopped {
            print( "Tried to stop, but already stopped" )
            return
        }
        
        if LocationService.isDebuggingLocation() {
            DebugLogger.instance.append( function: "LocationTracker.stop()", message:"Stop updating location" )
        }
        manager.stopUpdatingLocation()
        state = .stopped
    }
    
    //
    // CLLocationManager callbacks
    //
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation] ) {
        handleLocationChange( locations )
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DebugLogger.instance.append( function: "locationManager(:didFailWithError)", error:error )
    }
    
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        if let error = error {
            DebugLogger.instance.append( function: "locationManager(:didFinishDeferredUpdatesWithError)", error:error )
        }
        
        if let loc = manager.location {
            let locations = [loc]
            handleLocationChange( locations )
        }
    }
    
    //
    // Handle location update
    // throttle these changes to ~once a minute
    //
    
    // NOTE: this may happen in the background, so make sure to start a background task
    fileprivate func handleLocationChange( _ locations: [CLLocation] ) {
        
        guard let bestLocation = selectBestLocation( locations ) else {
            if LocationService.isDebuggingLocation() {
                DebugLogger.instance.append( function:"handleLocationChange()", message:"Failed to find good location... will keep trying" )
            }
            return
        }
        
        UIHelper.onMainThread {
            // did we already provide a good location within the last 60 seconds?
            if let lastLocation = self.mostRecentLocation {
                let interval = -lastLocation.timestamp.timeIntervalSinceNow
                if  interval < LocationTracker.locationFrequency {
                    if LocationService.isDebuggingLocation() {
                        DebugLogger.instance.append( "Ignoring location \(bestLocation) too soon after last location" )
                    }
                    return
                }
            }
            self.mostRecentLocation = bestLocation
            self.delegate?.onLocationChange( bestLocation )
        }
    }
    
    //
    // Utility
    //
    
    // filter out locations more than <locationLookback> seconds old
    // pick the location with the best horizontal accuracy
    fileprivate func selectBestLocation( _ locations: [CLLocation] ) -> CLLocation? {
        var best:CLLocation?
        
        let now = Date()
        for loc in locations {
            let age = -loc.timestamp.timeIntervalSince( now )    // seconds
            if age < LocationTracker.locationLookback {
                if best == nil {
                    best = loc
                } else if loc.horizontalAccuracy < best!.horizontalAccuracy {
                    best = loc
                } else if loc.horizontalAccuracy == best!.horizontalAccuracy {
                    // pick the newest one
                    if loc.timestamp.compare( best!.timestamp ) == .orderedDescending {
                        best = loc
                    }
                }
            }
        }
        
        return best
    }
}
