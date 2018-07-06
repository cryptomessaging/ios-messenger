//
//  HanekeHack.swift
//  Messenger
//
//  Created by Mike Prince on 11/10/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import Foundation
import Haneke

class HanekeHack {
    
    static let MAX_SECONDS:TimeInterval = 60 * 60 * 24    // 24 hours
    static let DEBUG = false
    
    class func isStale(_ key:String) -> Bool {
        let basepath = DiskCache.basePath()
        let filename = escapedFilename(key)
        let fullpath = NSString.path(withComponents: [basepath,"shared-images","original",filename])
        
        return fileAt(fullpath, isOlderThan:MAX_SECONDS )
    }
    
    class func escapedFilename(_ filename:String) -> String {
        let charactersToLeaveUnescaped = " \\" as NSString as CFString // TODO: Add more characters that are valid in paths but not in URLs
        let legalURLCharactersToBeEscaped = "/:" as NSString as CFString
        let encoding = CFStringBuiltInEncodings.UTF8.rawValue
        
        // Warning is OK, because we dont want to deviate from Haneke code
        let escapedPath1 = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, filename as CFString!, charactersToLeaveUnescaped, legalURLCharactersToBeEscaped, encoding)
        let allowedCharacters = NSCharacterSet(charactersIn: "/:").inverted
        let escapedPath2 = filename.addingPercentEncoding( withAllowedCharacters: allowedCharacters )
        if escapedPath1 as? String != escapedPath2 {
            print( "ERROR Whoa! escapedFilenames are different \(escapedPath1) != \(escapedPath2)" )
        } else {
            //print( "Yay!  They Match \(escapedPath1) = \(escapedPath2)" )
        }
        
        return escapedPath1 as! String
    }
    
    class func fileAt(_ path:String, isOlderThan maxSeconds:TimeInterval) -> Bool {
        let fileManager = FileManager.default
        do {
            let attr = try fileManager.attributesOfItem(atPath: path)
            let created = attr[FileAttributeKey.creationDate]!
            let seconds = -(created as AnyObject).timeIntervalSinceNow
            
            return seconds > maxSeconds
        } catch {
            if HanekeHack.DEBUG { print("Failed to determine file creation date", error as NSError) }
            return false
        }
    }
}
