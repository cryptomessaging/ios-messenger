import UIKit
import Foundation
import DLRadioButton

class SuggestedBotViewCell: UITableViewCell {
    
    struct Constants {
        static let Width:CGFloat = 120
        static let Height:CGFloat = UIConstants.InternalMargin * 2 + UIConstants.CardCoverDiameter
    }
    
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var taglineLabel: UILabel!
    @IBOutlet weak var coverImage: UIImageView! {
        didSet {
            let gearOverlay = GearOverlayView( frame: CGRect(x: 0, y: -6, width: Constants.Width, height: Constants.Height ) )
            
            gearOverlay.enabled = true
            contentView.addSubview( gearOverlay )
            contentView.bringSubview( toFront: gearOverlay )    // make sure its on top
        }
    }
    
    @IBOutlet weak var radioButton: DLRadioButton! {
        didSet {
            radioButton.isIconSquare = true
            radioButton.iconColor = self.tintColor
            radioButton.indicatorColor = self.tintColor
            radioButton.isUserInteractionEnabled = false
        }
    }
}

class CreateThreadWithBotsViewController: UITableViewController, UITextFieldDelegate {
    
    @IBOutlet weak var createButton: UIBarButtonItem!
    @IBOutlet weak var threadSubject: UITextField!
    
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var cardImage: UIImageView!
    @IBOutlet weak var cardNickname: UILabel!
    @IBOutlet weak var cardTagline: UILabel!
    
    @IBOutlet weak var botListHeader: UILabel!
    
    //fileprivate var myCards:[Card]?
    fileprivate var selectedCard:Card?
    
    fileprivate var allBotCards = [Card]()
    fileprivate var suggestedBotCards = [Card]()        // bots suggested as query is processed
    fileprivate var selectedBotCids = Set<String>()     // cids
    
    class func showCreateThread(_ nav:UINavigationController) {
        NavigationHelper.push( nav, storyboard:"CreateThreadWithBots", id:"CreateThreadWithBotsViewController" )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ImageHelper.round(cardImage)
        threadSubject.autocapitalizationType = .words
        
        threadSubject.delegate = self
        checkValidSubject() // to gray submit icon
        
        colorBotListHeader()
        
        // hook up a gesture recognizer for changing my card
        let gesture = UITapGestureRecognizer(target:self, action:#selector(changeCard))
        cardView.addGestureRecognizer(gesture)
        
        /*let progress = ProgressIndicator(parent:view, message:"Loading your cards".localized)
        CardHelper.loadMyCards(nil) {
            failure, cards, reputations in
            
            DispatchQueue.main.async(execute: {
                progress.stop()
                
                if let fail = failure {
                    ProblemHelper.showProblem(self, title:"Problem fetching your cards".localized, failure: fail ) {
                        self.unwind()
                    }
                } else*/
        
        if MyCardsModel.instance.cards.isEmpty {
            ProblemHelper.showProblem(self, title:"You have no cards!".localized, message: "Please create a card".localized ) {
                self.unwind()
            }
        } else {
            //self.myCards = cards
            showDefaultCard()
            loadBots()  // runs in background
        }
    }
    
    func unwind() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            print( "ERROR: Failed to find nav to unwind CreateThreadWithBotsViewController" )
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .createChat, vc:self )
    }
    
    fileprivate func showDefaultCard() {
        let cards = MyCardsModel.instance.cards
        let cid = MyUserDefaults.instance.getDefaultCardId()
        if let card = CardHelper.findCard(cid, inCards:cards) {
            selectedCard = card
        } else {
            selectedCard = cards[0]
        }
        showSelectedCard()
    }
    
    // gray bot list header when there are no bots
    fileprivate func colorBotListHeader() {
        botListHeader.textColor = suggestedBotCards.isEmpty ? UIColor.clear : UIColor.black
    }
    
    //
    // MARK: Bots want to help
    //
    
    fileprivate func loadBots() {
        PopularBotCardsModel.instance.fetchCards {
            failure, cards in
            
            guard let cards = cards else {
                return  // ignore failures
            }
            
            DispatchQueue.main.async {
                self.allBotCards.removeAll()
                for c in cards {
                    self.allBotCards.append( c )
                }
            }
        }
        
        /*MobidoRestClient.instance.fetchPopularBots {
            result in
            
            DispatchQueue.main.async(execute: {
                if let failure = result.failure {
                    ProblemHelper.showProblem(self,title:"Problem finding bots".localized, failure:failure )
                } else if let bots = result.bots {
                    self.allBotCards.removeAll()
                    for b in bots {
                        let card = Card()
                        card.cid = b.cid
                        card.nickname = b.nickname
                        
                        self.allBotCards.append( card )
                    }
                    
                    self.reviseSuggestedBots( self.threadSubject.text ?? "" )
                }
            })
        }*/
    }
    
    // based on the query/chat subject, pick which bots to show
    fileprivate func reviseSuggestedBots(_ query:String) {
        
        suggestedBotCards.removeAll()   // start fresh
        
        let lower = query.lowercased()
        let range = lower.startIndex ..< lower.endIndex
        lower.enumerateSubstrings( in:range, options:.byWords ) {
            word,_,_,_ in
            guard let keyword = word else {
                return
            }
            
            //let keyword = $0.substring!
            switch keyword {
            case "dinner":
                fallthrough
            case "beach":
                self.suggestBot( "PlanBot" )

            case "meet":
                fallthrough
            case "meeting":
                self.suggestBot( "WhenBot" )
                
            case "playdate":
                fallthrough
            case "picnic":
                self.suggestBot( "PlanBot" )
                self.suggestBot( "WhenBot" )
                
            case "map":
                self.suggestBot( "MapBot" )
                
            case "court":
                self.suggestBot( "HopoBot" )
             
            case "shopping":
                fallthrough
            case "grocery":
                fallthrough
            case "morning":
                fallthrough
            case "chore":
                fallthrough
            case "chores":
                fallthrough
            case "homework":
                fallthrough
            case "hw":
                self.suggestBot( "ChecklistBot" )
                self.suggestBot( "PayBot" )
                
            default: ()
                //print( "Unrecognized keyword \(keyword)" )
            }
        }
        
        colorBotListHeader()
        tableView?.reloadData()
    }
    
    fileprivate func suggestBot( _ nickname:String ) {
        // already in list?
        if findCardByNickname( suggestedBotCards, nickname: nickname ) != nil {
            return
        }
        
        // find card and add
        if let card = findCardByNickname( allBotCards, nickname: nickname ) {
            suggestedBotCards.append( card )
        }
    }
    
    fileprivate func findCardByNickname( _ cards:[Card], nickname:String ) -> Card? {
        for i in 0..<cards.count {
            let c = cards[i]
            if c.nickname == nickname {
                return c
            }
        }
        
        return nil
    }
    
    //
    // MARK: Table handling
    //
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return suggestedBotCards.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestedBotViewCell", for: indexPath) as! SuggestedBotViewCell
        
        let card = suggestedBotCards[indexPath.row]
        cell.nicknameLabel.text = card.nickname
        cell.taglineLabel.text = card.tagline
        
        ImageHelper.round(cell.coverImage!)
        ImageHelper.fetchCardCoverImage( card.cid!, ofSize:UIConstants.CardCoverSize, forImageView: cell.coverImage!)
        
        // selected?
        cell.radioButton.isSelected = selectedBotCids.contains( card.cid! )
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! SuggestedBotViewCell
        
        let cid = suggestedBotCards[indexPath.row].cid!
        if selectedBotCids.contains( cid ) {
            selectedBotCids.remove( cid )
            cell.radioButton.isSelected = false
        } else {
            selectedBotCids.insert( cid )
            cell.radioButton.isSelected = true
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    //
    // MARK: Card handling
    //
    
    fileprivate func showSelectedCard() {
        if let card = selectedCard {
            cardNickname.text = card.nickname
            cardTagline.text = card.tagline
            
            ImageHelper.fetchCardCoverImage(card.cid!, ofSize: UIConstants.CardCoverSize, forImageView: cardImage)
        } else {
            // TODO wha?!
            cardNickname.text = nil
            cardTagline.text = nil
            cardImage.image = nil
        }
    }
    
    //
    // MARK: Choose another card
    //
    
    func changeCard(_ sender: UITapGestureRecognizer) {
        MyCardChooserViewController.showCardChooser(navigationController!, cards: MyCardsModel.instance.cards ) {
            card in
            
            self.selectedCard = card
            self.showSelectedCard()
        }
    }
    
    //
    // MARK: UITextFieldDelegate
    //
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let current = threadSubject.text ?? ""
        let revised = (current as NSString).replacingCharacters(in: range, with: string)
        createButton.isEnabled = !revised.isEmpty
        
        // update suggested bots
        reviseSuggestedBots( revised )
        
        return true
    }
    
    fileprivate func checkValidSubject() {
        let text = threadSubject.text ?? ""
        createButton.isEnabled = !text.isEmpty
    }
    
    //
    // MARK: Handle nav bar buttons
    //
    
    @IBAction func cancelAction(_ sender: UIBarButtonItem) {
        navigationController!.popViewController(animated: true)
    }
    
    @IBAction func createAction(_ sender: UIBarButtonItem) {
        createButton.isEnabled = false
        let progress = ProgressIndicator(parent:view, message: "Creating chat".localized )
        
        // make sure values from form are in card object
        let thread = NewPublicChat()
        thread.cid = selectedCard!.cid
        thread.allcids = allCids()
        thread.subject = threadSubject.text
        
        MobidoRestClient.instance.createPublicChat(thread) {
            result in
            
            // cache locally while off main thread
            if let newthread = result.thread {
                ChatDatabase.instance.addThread(newthread)
            }
            
            DispatchQueue.main.async(execute: {
                progress.stop()
                self.handleNewThreadResult( result )
                self.createButton.isEnabled = true
            })
        }
    }
    
    // gather up my cid, and all the bot cids I've selected
    fileprivate func allCids() -> [String] {
        
        var cids = [String]()
        cids.append( selectedCard!.cid! )
        
        for c in suggestedBotCards {
            if selectedBotCids.contains( c.cid! ) {
                cids.append( c.cid! )
            }
        }
        
        return cids
    }
    
    // find the first cid that is not mine - assuming all other cids are bots
    fileprivate func firstBotCid(_ cids:[String]?) -> String? {
        if let cids = cids {
            for i in 0..<cids.count {
                if cids[i] != selectedCard!.cid! {
                    return cids[i]
                }
            }
        }
        
        return nil
    }
    
    // make sure this only happens on the main thread
    fileprivate func handleNewThreadResult( _ result:NewChatResult!) {
        if let failure = result.failure {
            ProblemHelper.showProblem(self, title:"Problem creating chat".localized, failure:failure)
        } else {
            AnalyticsHelper.trackResult(.chatCreated)
            
            // close this dialog, and open up new chat
            if let nav = navigationController {
                nav.popViewController(animated: false)
                
                let cached = CachedThread( src: result.thread! )
                let vc = GroupThreadViewController.showGroupThread(nav, thread: cached )
                
                // pop up a bot widget?
                vc.showBotWidgetOnStart( firstBotCid( result.thread!.cids ) )
            }
        }
    }
}
