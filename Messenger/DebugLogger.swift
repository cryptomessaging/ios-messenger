import Foundation
import ObjectMapper

//
// For saving debug log for remote diagnostics
// User can send this data to support to better help
//
class DebugLogger {
    static let instance = DebugLogger()
    static let DEBUG = false
    fileprivate let filename:String
    fileprivate let filemanager = FileManager.default
    var logging:Bool
    
    fileprivate init() {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        filename = documentsDirectory + "/debug.txt"
        logging = MyUserDefaults.instance.check( .IsLogging )
    }
    
    func append( function:String, error:Error ) {
        if( logging ) {
            append("\(function) \(error.localizedDescription)" )
        }
    }
    
    func append( function:String, failure:Failure ) {
        if( logging ) {
            append("\(function) \(failure)" )
        }
    }
    
    func append( function:String, preamble:String, json:Mappable ) {
        if( logging ) {
            append("\(function) \(preamble) \(String(describing: json.toJSONString()))" )
        }
    }
    
    func append( function:String, message:String ) {
        if( logging ) {
            append("\(function) \(message)" )
        }
    }
    
    func append( _ message:String ) {
        if !logging {
            return  // not logging
        }
        
        let log = "\(Date()): \(message)\r\n"
        if DebugLogger.DEBUG {
            print( "DebugLogger: \(log)" )
        }
        
        let data = log.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        
        if let fh = FileHandle( forUpdatingAtPath:filename ) {
            fh.seekToEndOfFile()
            fh.write(data)
            fh.closeFile()
            return
        }
        
        // write new file
        do {
            try data.write( to: URL(fileURLWithPath: filename), options: NSData.WritingOptions.atomicWrite )
        } catch {
            print( "Failed to write new file \(filename)" )
        }
    }

    func clear() {
        if filemanager.fileExists( atPath: filename ) {
            do {
                try filemanager.removeItem( atPath: filename )
            } catch {
                print( "Failed to clean out \(filename)" )
            }
        }
    }
    
    func read() -> Data {
        if let fh = FileHandle( forReadingAtPath:filename ) {
            return fh.readDataToEndOfFile()
        } else {
            return "- no log -".data(using: .utf8)!
        }
    }
    
    func readString() -> String {
        let data = read()
        let result = NSString( data:data, encoding:String.Encoding.utf8.rawValue )!
        return result as String
    }
}
