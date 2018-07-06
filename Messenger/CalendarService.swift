import Foundation
import EventKit

enum CalendarAccess: String {
    case Granted = "granted"
    case Pending = "pending"
    case Denied = "denied"
}

class CalendarService {
    static let DEBUG = false
    static let instance = CalendarService()
    
    fileprivate let eventStore = EKEventStore()
    
    init() {
        
    }
    
    func fetchFreeBusy(_ startDate:Date, endDate:Date, completion:@escaping ( _ access:CalendarAccess, _ schedule:FreeBusySchedule?) -> Void ) {
        checkAccess {
            access in
            
            var schedule:FreeBusySchedule?
            if access == .Granted {
                let query = self.eventStore.predicateForEvents(withStart: startDate, end:endDate, calendars: nil)
                let events = self.eventStore.events(matching: query)
                
                let tz = TimeZone.current
                schedule = FreeBusySchedule(startDate:startDate, endDate:endDate, events:events, tz:tz)
            }
            
            completion( access, schedule )
        }
    }
    
    func requestFreeBusyUpdates(_ startDate:Date, endDate:Date, webhook:String, tid:String, mycid:String, botcid:String, completion:@escaping (_ access:CalendarAccess) -> Void ) {
        checkAccess {
            access in
            
            // TODO add update support
            completion(access)
        }
    }
    
    func cancelFreeBusyUpdates( _ tid:String, mycid:String, botcid:String ) {
        // TODO
    }
    
    //
    // Public utility
    //
    
    class func toDates( _ startDay:Int, endDay:Int ) -> (startDate:Date, endDate:Date) {
        let cal = Calendar(identifier: Calendar.Identifier.gregorian)
        let now = Date()
        let lastMidnight = cal.startOfDay(for: now)   // TODO which timezone?
        
        let startDate = (cal as NSCalendar).date( byAdding: .day, value:startDay, to:lastMidnight, options:[] )!
        let endDate = (cal as NSCalendar).date( byAdding: .day, value:endDay, to:lastMidnight, options:[] )!
        
        return (startDate,endDate)
    }
    
    //
    // Utility
    //
    
    fileprivate func checkAccess(_ completion:@escaping (_ access:CalendarAccess) -> Void ) {
        let status = EKEventStore.authorizationStatus(for: EKEntityType.event)
        
        switch (status) {
        case EKAuthorizationStatus.notDetermined:
            // This happens on first-run
            requestAccessToCalendar( completion )
        case EKAuthorizationStatus.authorized:
            // Things are in line with being able to show the calendars in the table view
            completion( .Granted )
        case EKAuthorizationStatus.restricted, EKAuthorizationStatus.denied:
            // We need to help them give us permission
            askPermission( completion )
        }
    }
    
    fileprivate func requestAccessToCalendar( _ completion: @escaping (_ access:CalendarAccess) -> Void ) {
        eventStore.requestAccess(to: EKEntityType.event ) {
            accessGranted, error in
            
            if accessGranted {
                completion( .Granted )
            } else {
                DispatchQueue.main.async(execute: {
                    self.askPermission( completion )
                })
            }
        }
    }
    
    fileprivate func askPermission( _ completion:@escaping (_ access:CalendarAccess) -> Void ) {

        guard let vc = UIHelper.topVC() else {
            print( "Failed to get VC, not asking for calendar permission :(")
            return
        }
        
        // TODO localize
        let alert = UIAlertController(title:"Calendar Access".localized, message:"On the settings page, please give Mobido access to your calendar".localized, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: UIAlertActionStyle.default ) {
            action in
            let openSettingsUrl = URL(string: UIApplicationOpenSettingsURLString)
            UIApplication.shared.openURL(openSettingsUrl!)
            completion(.Pending)
        })
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel ) {
            action in
            completion(.Denied)
        })
        vc.present(alert, animated: true, completion: nil )
    }
}
