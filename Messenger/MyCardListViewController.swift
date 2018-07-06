import UIKit
import EasyTipView

class MyCardListViewController: UITableViewController, UIGestureRecognizerDelegate {
    
    fileprivate var addCardTip:EasyTipView?
    fileprivate var appearing = false   // track if we are appearing or not
    fileprivate var addCardButton: UIBarButtonItem!
    
    class func createMyCardListViewController() -> UIViewController {
        let vc = MyCardListViewController()
        vc.edgesForExtendedLayout = UIRectEdge()
        
        let nav = UINavigationController()
        nav.viewControllers = [vc]
        
        return nav
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // enable editing
        navigationItem.leftBarButtonItem = editButtonItem
        
        addCardButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createCardAction))
        navigationItem.rightBarButtonItem = addCardButton
        navigationItem.title = "My Cards (Title)".localized
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = UIConstants.LightGrayBackground
        
        tableView.separatorStyle = .none
        
        let longPressRecognizer = UILongPressGestureRecognizer(target:self,action:#selector(handleLongPress))
        longPressRecognizer.minimumPressDuration = 2.0  // 5 seconds!!
        longPressRecognizer.delegate = self
        tableView.addGestureRecognizer( longPressRecognizer )
        
        NotificationHelper.addObserver(self, selector: #selector(onMyCardsModelChanged), name: .myCardsModelChanged)
    }
    
    deinit {
        NotificationHelper.removeObserver(self)
    }
    
    func onMyCardsModelChanged() {
        tableView.reloadData()
        if MyCardsModel.instance.cards.isEmpty {
            self.showAddCardTip()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        
        // make sure cards are loaded
        MyCardsModel.instance.loadWithProblemReporting(.local, statusCallback:nil, completion:nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .myCards, vc:self )
        appearing = true
        if let tip = addCardTip {
            tip.isHidden = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        appearing = false
        if let tip = addCardTip {
            tip.isHidden = true
        }
    }
    
    // MARK: Navigation
    
    func createCardAction(_ sender: UIBarButtonItem) {
        if addCardTip != nil {
            addCardTip?.dismiss()
            addCardTip = nil
        }
        
        EditCardViewController.showCreateCard(navigationController!) {
            card in
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let card = MyCardsModel.instance.cards[indexPath.row]
        EditCardViewController.showEditCard(navigationController!, card: card)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    //
    // MARK: popover tip to create card
    //
    
    fileprivate func showAddCardTip() {
        UIHelper.delay( UIConstants.TipDelay ) {
            if self.addCardTip != nil {
                return
            }
            
            if self.appearing {
                self.addCardTip = EasyTipView(text: "Click here to create first card".localized)
                self.addCardTip?.show(forItem: self.addCardButton,
                                      withinSuperView: self.navigationController?.view)
            }
        }
    }
    
    //
    // MARK: Table handling
    //
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return MyCardsModel.instance.cards.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        let subviews = cell.contentView.subviews
        var cardView:FullCardView
        if subviews.isEmpty {
            cardView = FullCardView.loadFromNib()
            cell.contentView.addSubview(cardView)
            cell.backgroundColor = UIConstants.LightGrayBackground
        } else {
            cardView = subviews.first as! FullCardView
        }
        
        let card = MyCardsModel.instance.cards[indexPath.row]
        cardView.setCard( card, tid:nil)
        
        // size the frame
        let width = view.frame.width
        let size = FullCardView.findSize(card, width:width )
        cardView.frame = CGRect(x: 0,y: 0, width: width, height: size.height )
        
        return cell
    }
    
    override func tableView( _ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let card = MyCardsModel.instance.cards[indexPath.row]
        let size = FullCardView.findSize(card, width: view.frame.width )
        return size.height
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let progress = ProgressIndicator(parent: view,message:"Deleting card".localized)
            let card = MyCardsModel.instance.cards[indexPath.row]
            MobidoRestClient.instance.deleteCard(card.cid!) {
                result in
                DispatchQueue.main.async(execute: {
                    progress.stop()
                    self.handleDeleteCardResult(result, indexPath:indexPath)
                })
            }

        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    
    //
    // MARK: Deletes
    //
    
    // always do on main thread
    fileprivate func handleDeleteCardResult(_ result:BaseResult, indexPath: IndexPath) {
        if ProblemHelper.showProblem(self, title: "Problem removing card from server".localized, failure: result.failure ) == false {
            MyCardsModel.instance.remove(index: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            NotificationHelper.signal(.cardsDeleted)
        }
    }
    
    //
    // Handle long press for metaurl and market settings
    //
    
    func handleLongPress(gestureRecognizer:UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            let p = gestureRecognizer.location(in:tableView)
            if let indexPath = tableView.indexPathForRow(at:p) {
                let card = MyCardsModel.instance.cards[indexPath.row]
                showAdvancedMenu(card, atLocation:p )
            }
        }
    }
    
    func showAdvancedMenu(_ card:Card, atLocation point:CGPoint ) {
        let alert = UIAlertController(title: card.nickname, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        let metapageAction = UIAlertAction(title: "Metapage (Action)".localized, style: .default, handler: {
            action in
            self.editMetaUrl(card)
        })
        alert.addAction( metapageAction )
        
        let updateMarketAction = UIAlertAction(title: "Update Market (Action)".localized, style: .default, handler: {
            action in
            self.updateMarketCategory(card)
        })
        alert.addAction(updateMarketAction)
        
        let enterBetaAction = UIAlertAction(title: "Enter Beta (Action)".localized, style: .default, handler: {
            action in
            let updates = MarketCategoryUpdates()
            updates.categories = ["beta":"10"];
            self.updateMarketCategory2(card, errorTitle:"Problem Entering Beta (Error)".localized, updates:updates )
        })
        alert.addAction(enterBetaAction)
        
        let leaveMarketAction = UIAlertAction(title: "Leave Market (Action)".localized, style: .destructive, handler: {
            action in
            self.confirmLeaveMarket(card)
        })
        alert.addAction(leaveMarketAction)
        
        UIHelper.ipadFixup( alert, atLocation:point, inView:self.view )
        present(alert, animated: true, completion: nil)
        AnalyticsHelper.trackPopover( .cardAdvancedOptions, vc:alert )
    }
    
    // metaurl/metapage
    
    fileprivate func editMetaUrl(_ card:Card) {
        let alert = UIAlertController(title: "Metapage URL".localized, message: nil, preferredStyle: .alert )
        alert.addTextField {
            field in
            field.text = card.metaurl
        }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: {
            action in
            
            self.editMetaUrl2(card, url:StringHelper.clean( alert.textFields!.first!.text ) )
        }))
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func editMetaUrl2(_ card:Card, url:String? ) {
        let progress = ProgressIndicator(parent: view,message:"Updating Metapage (Progress)".localized)
        MobidoRestClient.instance.setMetaUrl(url, cid:card.cid! ) {
            result in
            
            progress.stop()
            if ProblemHelper.showProblem(self,title:"Problem Updating Metapage", failure:result.failure ) {
                // cry cry
            } else {
                card.metaurl = url
                MyCardsModel.instance.updateMyCardInCache(card, flushMedia: false)
            }
        }
    }
    
    // update market category
    
    fileprivate func updateMarketCategory(_ card:Card) {
        let alert = UIAlertController(title: "Update Category".localized, message: nil, preferredStyle: .alert )
        alert.addTextField {
            field in
            //field.text = card.metaurl
            field.placeholder = "Market Category (Placeholder)".localized
        }
        alert.addTextField {
            field in
            //field.text = card.metaurl
            field.placeholder = "Category Value (Placeholder)".localized
        }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: {
            action in
            
            guard let category = StringHelper.clean( alert.textFields![0].text ) else {
                return
            }
            
            let updates = MarketCategoryUpdates()
            let value = StringHelper.clean( alert.textFields![1].text ) // ok to be null
            updates.categories = [category:value];
            updates.passcode = MyUserDefaults.instance.get( .MARKET_PASSCODE )
            self.updateMarketCategory2(card, errorTitle:"Problem Updating Category (Error)".localized, updates:updates )
        }))
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func updateMarketCategory2(_ card:Card, errorTitle:String, updates:MarketCategoryUpdates ) {
        let progress = ProgressIndicator(parent: view,message:"Updating Category (Progress)".localized)
        MobidoRestClient.instance.updateMarketCategories(card.cid!, updates:updates ) {
            result in
            
            progress.stop()
            ProblemHelper.showProblem( self, title:errorTitle, failure:result.failure )
        }
    }
    
    // leave market
    
    fileprivate func confirmLeaveMarket(_ card:Card) {
        let alert = UIAlertController(title: "Leave Market?".localized, message: "This removes this persona from all categories in the market".localized, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: {
            action in
            self.leaveMarket(card)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func leaveMarket(_ card:Card) {
        let progress = ProgressIndicator(parent: view,message:"Leaving Market (Progress)".localized)
        MobidoRestClient.instance.removeCardFromMarket( card.cid! ) {
            result in
            
            progress.stop()
            ProblemHelper.showProblem(self,title:"Problem Leaving Market", failure:result.failure )
        }
    }
}
