//
//  HttpClient.swift
//  Messenger
//
//  Created by Mike Prince on 12/1/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import Foundation

class HttpClient {
    
    class func fetch(_ url:URL, onSuccess:@escaping (Data)->(), onFailure:((Failure)->())? ) {
        let urlSession = URLSession.shared
        let task = urlSession.dataTask(with: url, completionHandler: {
            (data,response,error) -> Void in
        
            // networking problem?
            if let error = error {
                let failure = Failure(message: error.localizedDescription)
                self.logFailure( failure, url:url )
                onFailure?( failure )
                return
            }
        
            // HTTP response problem?
            let httpResponse = response as? HTTPURLResponse
            if httpResponse == nil {
                // strange
                let failure = Failure(message:"HTTP response is irregular".localized)
                self.logFailure( failure, url:url )
                onFailure?(failure)
                return
            }
        
            let code = httpResponse!.statusCode
            if code != 200 {
                let message = HTTPURLResponse.localizedString(forStatusCode: httpResponse!.statusCode)
                let failure = Failure(statusCode: code == 401 ? 0 : code, message:message)
                self.logFailure( failure, url:url )
                onFailure?(failure)    // scrub 401s so they dont cause login
                return
            }
            
            if let data = data {
                DebugLogger.instance.append( "SUCCESS: fetched \(data.count) bytes from \(url)" )
                onSuccess(data)
            } else {
                onFailure?( Failure(message:"HTTP response had no data".localized ) )
            }
        }) 
        
        DebugLogger.instance.append( "Fetching: \(task.taskIdentifier) GET \(url)" )
        task.resume()
    }
    
    class func logFailure( _ failure:Failure, url:URL ) {
        let statusCode = failure.statusCode == nil ? -1 : failure.statusCode;
        DebugLogger.instance.append( "FAILURE: \(String(describing: statusCode)) \(failure.message!) \(url)" )
    }
}
