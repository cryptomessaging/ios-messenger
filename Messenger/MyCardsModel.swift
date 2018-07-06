//
//  MyCardsModel.swift
//  Messenger
//
//  One layer above the disk cache - the in-memory model that's shared between view controllers.
//  Can be used as a DataSource for TableViews.
//
//  load(.local) uses any locally cached values, this should be called before using any values
//  load(.server) makes sure the cached values came from the server
//
//  Created by Mike Prince on 3/12/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class MyCardsModel {
    static let instance = MyCardsModel()
    static let DEBUG = false
    
    var cards = [Card]()
    var reputations = [String: Reputation]()
    var cardIds = Set<String>()
    
    enum State {
        case dirty
        case localLoaded
        case serverLoaded
    }
    
    fileprivate var state:State = .dirty
    
    fileprivate init() {
        if MyCardsModel.DEBUG { print("MyCardsModel.init()") }
    }
    
    deinit {
        if MyCardsModel.DEBUG { print("MyCardsModel.deinit()") }
    }
    
    func clear() {
        if MyCardsModel.DEBUG { print("MyCardsModel.clear)") }
        cards.removeAll()
        reputations.removeAll()
        cardIds.removeAll()
        state = .dirty
    }
    
    // refresh and display any problems
    func loadWithProblemReporting( _ source:DataSource, statusCallback:StatusCallback?, completion:((_ success:Bool)->Void)? ) {
        if MyCardsModel.DEBUG { print( "refresh1") }
        load(source, statusCallback:statusCallback) {
            failure in
            
            let success = ProblemHelper.showProblem(nil, title:"Problem fetching my cards from server (Title)".localized, failure: failure) == false
            completion?(success)
        }
    }
    
    // full card refresh including reputations
    func load( _ source:DataSource, statusCallback:StatusCallback?, completion:((_ failure:Failure?) -> Void)? ) {
        if source == .local && state != .dirty {
            completion?(nil)
            return
        }
        
        if MyCardsModel.DEBUG { print( "refresh2") }
        let cache = GeneralCache.instance
        if source == .local, let reputations = cache.loadMyReputations() {
            self.reputations = reputations
            load( source, updateReputations:false, statusCallback:statusCallback, completion:completion )
        } else {
            MobidoRestClient.instance.fetchMyReputations {
                result in
                
                if let failure = result.failure {
                    completion?( failure )
                    return
                }
                
                if let reputations = result.reputations {
                    self.reputations = reputations
                } else {
                    self.reputations.removeAll()
                }
                
                // cache even empty sets
                cache.saveMyReputations(self.reputations)
                
                self.load( source, updateReputations:true, statusCallback:statusCallback, completion:completion )
            }
        }
    }
    
    fileprivate func load( _ source:DataSource, updateReputations:Bool, statusCallback:StatusCallback?, completion:((_ failure:Failure?) -> Void)? ) {
        if MyCardsModel.DEBUG { print( "cardRefresh") }
        
        // cached?
        if source == .local, let cards = GeneralCache.instance.loadMyCardList() {
            if updateReputations {
                for c in cards {
                    CardHelper.resolveReputations( c, reputations: self.reputations )
                }
                
                // reputations may have changed, so update cache
                GeneralCache.instance.saveMyCardList(cards)
            }
            
            update(cards: cards)
            state = .localLoaded
            completion?( nil )
            return
        }
        
        // pull cards from server
        statusCallback?.onStatus("Fetching your cards".localized)
        MobidoRestClient.instance.listMyCards {
            result in
            
            if let failure = result.failure {
                completion?( failure )
                return
            }
            
            guard let cards = result.cards else {
                completion?(nil)
                return
            }
            
            // sort
            let sorted = cards.sorted {
                let r = $0.created!.localizedCompare($1.created!)
                return r == ComparisonResult.orderedDescending
            }
            
            // always fixup reputations
            for c in cards {
                CardHelper.resolveReputations( c, reputations: self.reputations )
            }
            
            // cache for later
            self.state = .serverLoaded
            statusCallback?.onStatus("Caching your cards".localized )
            GeneralCache.instance.saveMyCardList(sorted)
            self.update(cards:sorted)
            completion?( nil )
        }
    }
    
    func remove(index:Int) {
        cards.remove(at: index)
        GeneralCache.instance.saveMyCardList(cards)
        self.cardIds = CardHelper.getCardIds(cards)
    }
    
    func updateMyCardInCache( _ card:Card, flushMedia:Bool ) {
        let cache = GeneralCache.instance
        if var cards = cache.loadMyCardList() {
            
            if let i = CardHelper.findCardIndex( card.cid, inCards:cards ) {
                cards.remove(at: i)
            }
            
            cards.insert(card, at: 0)
            cache.saveMyCardList(cards)
            update(cards:cards)
        } else {
            let cards = [ card ]
            cache.saveMyCardList(cards)
            update(cards:cards)
        }
        
        LruCache.instance.saveCard(card)
        if flushMedia {
            LruCache.instance.removeCardCoverImage(card.cid!, size: UIConstants.CardCoverSize )
        }
    }
    
    func isMyCid(cid:String) -> Bool {
        for id in cardIds {
            if id == cid {
                return true
            }
        }
        
        return false
    }
    
    fileprivate func update(cards:[Card]) {
        self.cards = cards
        self.cardIds = CardHelper.getCardIds(cards)
        NotificationHelper.signal(.myCardsModelChanged)
    }
}
