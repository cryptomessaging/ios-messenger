import Foundation

struct Seconds {
    static let IN_ONE_HOUR = 60 * 60
    static let FROM_1970_TO_2000 = 978307200
    static let IN_TWO_MINUTES:Double = 120
}

struct Millis {
    static let IN_ONE_MINUTE = 60 * 1000;
}

class TimeHelper {

    static let ISO8601 = "yyyy-MM-dd'T'HH:mm:ssX"
    static let ISO8601_MILLIS = "yyyy-MM-dd'T'HH:mm:ss.SSSX"
    
    fileprivate static let formatter:DateFormatter = {
        var formatter = DateFormatter()
        
        formatter.dateFormat = ISO8601
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: Calendar.Identifier.iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        return formatter
    }()
    
    fileprivate static let milliFormatter:DateFormatter = {
        var formatter = DateFormatter()
        
        formatter.dateFormat = ISO8601_MILLIS
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: Calendar.Identifier.iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        return formatter
    }()
    
    fileprivate static let prettyFormatter:DateFormatter = {
        var formatter = DateFormatter()
        
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        
        //formatter.timeZone = systemTimeZone()
        //formatter.calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierISO8601)!
        //formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        
        return formatter
    }()
    
    static func asYmd( _ date: Date ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    static func parseYmdToDate( _ ymd:String ) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date( from: ymd )
    }
    
    static func as8601( _ date: Date ) -> String {
        return formatter.string(from: date)
    }
    
    static func as8601Millis( _ date: Date ) -> String {
        return milliFormatter.string(from: date)
    }
    
    static func nowAs8601() -> String {
        return formatter.string( from: Date() )
    }
    
    static func recentAs8601(_ secondsAgo:Int) -> String {
        let ago = TimeInterval( -secondsAgo )
        let recent = Date().addingTimeInterval(ago)
        
        return as8601( recent )
    }
    
    static func asDate( _ time:String? ) -> Date? {
        if let t = time {
            let formatter = DateFormatter()
            formatter.dateFormat = hasMillis(t) ? ISO8601_MILLIS : ISO8601
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter.date( from: t )
        } else {
            return nil
        }
    }
    
    static func hasMillis(_ s:String) -> Bool {
        return s.range(of: ".") != nil
    }
    
    // compare two ISO8601 strings to see which is newer
    static func isAscending(_ t1:String?, t2:String? ) -> Bool {
        var result:ComparisonResult
        if t1 == nil {
            // t1/nil = 0, so next is higher ;)
            result = ComparisonResult.orderedAscending
        } else if t2 == nil {
            // anything is higher than t2/nil/0, so next is lower
            result = ComparisonResult.orderedDescending
        } else {
            result = t1!.localizedCompare(t2!)
        }
        return result == ComparisonResult.orderedAscending
    }
    
    static func getSeconds() -> Int {
        
        let now = CFAbsoluteTimeGetCurrent()
        let seconds = now + Double(Seconds.FROM_1970_TO_2000)  // from y2k seconds to epoch/1970 seconds
        
        return Int( seconds )
    }
    
    static func getMillis() -> Int64 {
        
        let now = CFAbsoluteTimeGetCurrent()
        let adjusted = now + Double(Seconds.FROM_1970_TO_2000)  // from y2k seconds to epoch/1970 seconds
        let millis = adjusted * 1000
        
        return Int64( millis )
    }
    
    // compare previous CFAbsoluteTimeGetCurrent() to now
    // return seconds
    static func pastTime( _ previousTime:Double ) -> Double {
        let now = CFAbsoluteTimeGetCurrent()
        return now - previousTime
    }
    
    static func getMillisDurationSince( _ start:Int64 ) -> Int64 {
        return getMillis() - start;
    }
    
    static func asPrettyDate( _ date:Date ) -> String {
        // in the future?
        let interval = date.timeIntervalSinceNow
        if interval > 0 {
            // in the future!?
            return prettyFormatter.string(from: date)
        } else if interval > -120 {
            let seconds = -Int(interval)
            return String(format:"%d seconds ago".localized, seconds)
        } else if interval > -3600 {
            let minutes = -Int( interval / 60 )
            return String(format:"%d minutes ago".localized, minutes)
        }
        
        return asRecentDate( date )
    }
    
    // this won't show a time when it's been only a few minutes
    static func asMessageDate( _ date:Date ) -> String? {
        let interval = date.timeIntervalSinceNow    // in seconds
        if interval > 0 {
            // in the future!?
            return prettyFormatter.string(from: date)
        } else if interval > -300 { // less than 5 minutes ago?
            return nil  // up to 5 minutes, don't show a time
        } else if interval > -3600 { // less than an hour ago?
            let minutes = -Int( interval / 60 )
            return String(format:"%d minutes ago".localized, minutes)
        }
        
        return asRecentDate( date )
    }
    
    static func asRecentDate( _ date: Date ) -> String {
        // if since midnight last night... then just show hours
        let startOfToday = Calendar.current.startOfDay(for: Date())
        if startOfToday.compare( date ) == ComparisonResult.orderedAscending {
            return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        }
        
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
    
    static func calculateAge(_ birthday:Date) -> Int {
        let now = Date()
        
        let gregorian = Calendar(identifier: Calendar.Identifier.gregorian)
        let ageComponents = (gregorian as NSCalendar).components(.year, from: birthday, to: now, options: .matchStrictly)
        let age = ageComponents.year
        return age!
    }
}
