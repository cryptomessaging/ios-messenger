import Foundation
import ObjectMapper
import CoreLocation
import EventKit

enum RangePosition {
    case `in`
    case after
}

class FreeBusySchedule: Mappable {
    static let DEBUG = false
    
    var start:Double!
    var end:Double!
    var tz:String!
    var busy:[[Double]] = []  // ordered list of two element arrays containing [start,end] in epoch seconds
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        start <- map["start"]
        end <- map["end"]
        tz <- map["tz"]
        busy <- map["busy"]
    }
    
    init(startDate:Date, endDate:Date, events:[EKEvent], tz:TimeZone) {
        start = startDate.timeIntervalSince1970
        end = endDate.timeIntervalSince1970
        self.tz = tz.identifier
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        for e in events {
            if FreeBusySchedule.DEBUG {
                let tz = e.timeZone ?? TimeZone.current
                formatter.timeZone = tz
                let start = formatter.string(from: e.startDate)
                let end = formatter.string(from: e.endDate)
                print( "Merging \(start) to \(end) tz \(tz) from \(e)")
            }

            mergeBusyTime( e.startDate, end: e.endDate )

            if FreeBusySchedule.DEBUG {
                dump()
                verify()
            }
        }
        
        dump()
    }
    
    fileprivate func verify() {
        for (index,e) in busy.enumerated() {
            if e[0] > e[1] {
                print( "ERROR: start after end in \(e)" )
            }
            
            if index > 0 {
                let previous = busy[index-1]
                if previous[1] >= e[0] {
                    print( "ERROR: end from previous \(previous) > start of \(e)" )
                }
            }
        }
    }
    
    fileprivate func timeRange( _ start:Double, end:Double ) -> [Double] {
        return [start,end]
    }
    
    fileprivate func mergeBusyTime( _ start:Date, end:Date ) {
        let startSeconds = start.timeIntervalSince1970
        let endSeconds = end.timeIntervalSince1970
        
        if FreeBusySchedule.DEBUG {
            print( "event from \(start)-\(end)" )
            let json = self.toJSONString()!
            print( "merging \(startSeconds)-\(endSeconds) into \(json)" )
        }
        
        // if the list is empty, or the new range starts after the last, then
        // simply append
        if busy.isEmpty || startSeconds > busy.last![1] {
            busy.append( timeRange( startSeconds, end: endSeconds ) )
            if FreeBusySchedule.DEBUG { print( "Appending") }
            return
        }
        
        // two more possibilities...

        // 1) start is before first range
        if startSeconds < busy[0][0] {
            let (pos,index) = findTimeRangeContaining( endSeconds )
            if pos == .after && index == busy.count - 1  {
                if FreeBusySchedule.DEBUG { print( "Replacing all") }
                // end is AFTER last entry, so simply clear list and add my new range
                busy.removeAll()
                busy.append( timeRange( startSeconds, end: endSeconds ) )
            } else if pos == .in {
                if FreeBusySchedule.DEBUG { print( "Expanding \(index) to cover all previous") }
                // end time is within the indexed entry, so update start time of changed indexed entry, and remove
                // all entries before it
                busy[index][0] = startSeconds
                busy.removeSubrange( 0..<index )
            } else { // pos == .After
                if FreeBusySchedule.DEBUG { print( "Expanding \(index) to cover all previous AND extending to \(endSeconds)") }
                // end time is after the indexed entry, but before the next, so extend first range to start and end, and remove all
                // entries in between
                busy[index][0] = startSeconds
                busy[index][1] = endSeconds
                busy.removeSubrange( 0..<index )
            }
            return
        }
        
        // 2) start is in an existing range OR in between a middle range
        let (startPos,startIndex) = findTimeRangeContaining( startSeconds )
        let (endPos,endIndex) = findTimeRangeContaining( endSeconds )
        if startIndex == endIndex {
            // start and end are in same range...
            if startPos == .in && endPos == .in {
                // totally contained, so nothing to do...
            } else if startPos == .in && endPos == .after {
                // extend range
                busy[startIndex][1] = endSeconds
            } else if startPos == .after && endPos == .after {
                // add a new range after this range
                busy.insert( timeRange(startSeconds, end: endSeconds), at: startIndex + 1 )
            } else { // startPos == .After && endPos == .In
                print( "Impossible! start is after end!" )
            }
            
            return
        }
        
        // handle all cases where startIndex and endIndex are different
        if FreeBusySchedule.DEBUG { print( "Merging \(startPos):\(startIndex) and \(endPos):\(endIndex)" ) }
        if startPos == .in && endPos == .in {
            // merge end range into start range
            busy[startIndex][1] = busy[endIndex][1]
            removeRange( (startIndex+1)...endIndex )
        } else if startPos == .after && endPos == .in {
            // extend next range back to start
            busy[endIndex][0] = startSeconds
            removeRange( (startIndex+1)..<endIndex )
        } else if startPos == .after && endPos == .after {
            busy[endIndex][0] = startSeconds
            busy[endIndex][1] = endSeconds
            removeRange( (startIndex+1)..<endIndex )
        } else { // startPos == .In && endPos == .After
            busy[startIndex][1] = endSeconds
            removeRange( (startIndex+1)...endIndex )
        }
    }
    
    fileprivate func removeRange( _ range:Range<Int> ) {
        if range.lowerBound <= range.upperBound {
            busy.removeSubrange( range )
        } else {
            if FreeBusySchedule.DEBUG { print( "NOT removing range \(range)" ) }
        }
    }
    
    fileprivate func removeRange( _ range:ClosedRange<Int> ) {
        if range.lowerBound <= range.upperBound {
            busy.removeSubrange( range )
        } else {
            if FreeBusySchedule.DEBUG { print( "NOT removing range \(range)" ) }
        }
    }
    
    // If time is before first element this returns (.After,-1)
    fileprivate func findTimeRangeContaining( _ time:Double ) -> (RangePosition,Int) {
        for (index,e) in busy.enumerated() {
            if time >= e[0] && time <= e[1] {
                return (.in,index)
            } else if time < e[0] {
                return (.after, index - 1)
            }
        }
        
        // we ran past end of array, say after last element
        return (.after,busy.count - 1)
    }
    
    fileprivate func dump() {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        
        for (index,e) in busy.enumerated() {
            let start = formatter.string(from: Date(timeIntervalSince1970:e[0]))
            let end = formatter.string(from: Date(timeIntervalSince1970:e[1]))
            if FreeBusySchedule.DEBUG { print( "[\(index)] Busy \(start) to \(end)" ) }
        }
    }
}
