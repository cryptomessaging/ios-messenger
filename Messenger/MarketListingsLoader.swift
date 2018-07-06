//
//  BotListingsLoader.swift
//  Messenger
//
//  Created by Mike Prince on 3/5/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class MarketListingsLoader {
    
    class func fetch(_ category:MarketCategory, completion:@escaping (Failure?,[MarketListing]?)->Void ) {
        // a recent cached version?
        let cache = GeneralCache.instance
        if let cached = cache.loadMarketListings(category) {
            let interval = cached.created.timeIntervalSinceNow
            if interval > -3600 {   // 3600=1 hour in seconds
                completion(nil,cached.listings)
                return
            }
        }
        
        // go across wire
        MobidoRestClient.instance.fetchMarketListingsByCategory(category) {
            result in
            
            if let failure = result.failure {
                completion(failure,nil)
            } else if let listings = result.listings {
                cache.saveMarketListings(listings, category: category)
                completion(nil,listings)
            } else {
                completion(nil,nil)
            }
        }
    }
}
