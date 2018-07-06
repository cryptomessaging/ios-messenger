import Foundation

class CidHolder : HasCardId {
    var cid:String?
    init(_ cid:String) {
        self.cid = cid
    }
}

// TODO Yikes - hard coded to bot server... ok?
class CoachCardsModel : CardListHolder<CidHolder> {
    static let instance = CoachCardsModel()
    static let botRestClient = BotRestClient( baseUrl: URL( string:"http://bots.mobido.com/a/coach/" )! )
    
    fileprivate var lastIdsLoad:Double = 0
    fileprivate var cardIds:[String]?
    
    func fetchCardIds( completion:@escaping ([String])->Void ) {
        let age = TimeHelper.pastTime( lastIdsLoad )
        if age < Seconds.IN_TWO_MINUTES {
            completion( cardIds! )
        } else {
            
            func callback(result:CardIdsResult) -> Void {
                if let failure = result.failure {
                    ProblemHelper.showProblem(nil, title: "Failed To Fetch Available Coaches (Title)".localized, failure: failure)
                } else if let cids = result.cids {
                    self.cardIds = cids
                    self.lastIdsLoad = CFAbsoluteTimeGetCurrent()
                    completion(cids)
                }
            }
            CoachCardsModel.botRestClient.httpFetch("GET", path:"available", secure:false, callback:callback )
        }
    }
    
    func fetchCards( updates:@escaping (Failure?,[Card]?)->Void ) {
        let age = TimeHelper.pastTime( lastCardLoad )
        if age < TWO_MINUTES_IN_SECONDS {
            updates(nil,cardsLoaded)
            return
        }
        
        func completion(result:CardIdsResult) -> Void {
            if let failure = result.failure {
                ProblemHelper.showProblem(nil, title: "Failed To Fetch Available Coaches (Title)".localized, failure: failure)
            } else {
                var list = [CidHolder]()
                for cid in result.cids! {
                    list.append( CidHolder(cid) )
                }
                
                UIHelper.onMainThread {
                    self.loadCards( list, updates:updates )
                }
            }
        }
        CoachCardsModel.botRestClient.httpFetch("GET", path:"available", secure:false, callback:completion )
    }
}

class PopularBotCardsModel : CardListHolder<MarketListing> {
    static let instance = PopularBotCardsModel()
    
    func fetchCards( updates:@escaping (Failure?,[Card]?)->Void ) {
        let age = TimeHelper.pastTime( lastCardLoad )
        if age < ONE_HOUR_IN_SECONDS {
            updates(nil,cardsLoaded)
            return
        }
        
        MarketListingsLoader.fetch(.popular) {
            failure, listings in
            
            if !ProblemHelper.showProblem(nil, title: "Failed To Fetch Popular Bots (Title)".localized, failure: failure) {
                UIHelper.onMainThread {
                    self.loadCards( listings, updates:updates )
                }
            }
        }
    }
}

class RecommendedBotCardsModel : CardListHolder<MarketListing> {
    static let instance = RecommendedBotCardsModel()
    
    func fetchCards( updates:@escaping (Failure?,[Card]?)->Void ) {
        let age = TimeHelper.pastTime( lastCardLoad )
        if age < ONE_HOUR_IN_SECONDS {
            updates(nil,cardsLoaded)
            return
        }
        
        MarketListingsLoader.fetch(.recommended) {
            failure, listings in
            
            if !ProblemHelper.showProblem(nil, title: "Failed To Fetch Recommended Bots (Title)".localized, failure: failure) {
                UIHelper.onMainThread {
                    self.loadCards( listings, updates:updates )
                }
            }
        }
    }
}

class HomepageBotCardsModel : CardListHolder<MarketListing> {
    static let instance = HomepageBotCardsModel()
    
    // this does not showProblem on failures, it's left up to the caller
    func fetchCards( updates:@escaping (Failure?,[Card]?)->Void ) {
        let age = TimeHelper.pastTime( lastCardLoad )
        if age < ONE_HOUR_IN_SECONDS {
            updates(nil,cardsLoaded)
            return
        }
        
        MarketListingsLoader.fetch(.homepage) {
            failure, listings in
            
            if let failure = failure {
                //ProblemHelper.showProblem(nil, title: "Failed To Fetch Homepage Bots (Title)".localized, failure: failure)
                updates( failure, nil )
                return
            }

            UIHelper.onMainThread {
                self.loadCards( listings, updates:updates )
            }
        }
    }
}

class CardListHolder<T: HasCardId> {
    let ONE_HOUR_IN_SECONDS:Double = 3600
    let TWO_MINUTES_IN_SECONDS:Double = 120

    var cardsLoaded = [Card]()
    
    //fileprivate var lastCardIds:[T]?
    var lastCardLoad:Double = 0
    
    func clear() {
        cardsLoaded.removeAll()
        lastCardLoad = 0
    }
    
    // NOTE: must be called on main thread!!
    fileprivate func loadCards( _ cidholders:[T]?, updates:@escaping (Failure?,[Card]?)->Void ) {
        guard let cidholders = cidholders else {
            return
        }
        
        for holder in cidholders {
            if let cid = holder.cid {
                if CardHelper.findCard(cid, inCards: cardsLoaded) == nil {
                    // Card hasnt been loaded yet, so fetch!
                    fetchPublicCard( cidholders, cid:cid, updates:updates )
                }
            }
        }
        
        // if we already have any cards, send up what we have!
        if cardsLoaded.isEmpty == false {
            updates( nil, orderCards( cidholders ) )
        }
    }
    
    fileprivate func fetchPublicCard( _ cidholders:[T], cid:String, updates:@escaping (Failure?,[Card]?)->Void) {
        CardHelper.fetchPublicCard(cid) { card, failure in
            if let failure = failure {
                updates( failure, nil )
            }
            
            guard let card = card else {
                return
            }

            // update list in main thread to avoid race conditions, as they come in
            UIHelper.onMainThread {
                // make sure card wasnt loaded by a parallel effort
                if CardHelper.findCard(card.cid!, inCards: self.cardsLoaded) == nil {
                    self.cardsLoaded.append( card )
                    self.checkAllCardsLoaded(cidholders)
                    let orderedCards = self.orderCards(cidholders)
                    updates( nil, orderedCards )
                }
            }
        }
    }
    
    fileprivate func checkAllCardsLoaded(_ cidholders:[T] ) {
        for holder in cidholders {
            if CardHelper.findCard( holder.cid!, inCards: cardsLoaded ) == nil {
                return
            }
        }
        
        // found all the cards!
        lastCardLoad = CFAbsoluteTimeGetCurrent()
        //lastCardIds = cidholders
    }
    
    // get cards from botCardsLoaded, and order the cards in botListings order
    // NOTE: must be called on main thread
    fileprivate func orderCards(_ cidholders:[T] ) -> [Card] {
        var orderedCards = [Card]()
        
        for c in cidholders {
            if let card = CardHelper.findCard(c.cid, inCards: cardsLoaded ) {
                orderedCards.append(card)
            }
        }
        
        return orderedCards
    }
}
