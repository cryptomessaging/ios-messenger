//
//  AddToChatViewController.swift
//  Messenger
//
//  Created by Mike Prince on 3/23/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

protocol AddHandler: class {
    func addBot( _ vc:UIViewController, botcard:Card, completion:@escaping(_ success:Bool)->Void )
    func addCoach( _ vc:UIViewController, cid:String, completion:@escaping(_ success:Bool)->Void )
    func addContacts( _ vc:UIViewController, contactList:[ChatContact], completion:@escaping(_ success:Bool)->Void )
}

class AddToChatViewController : UITableViewController, OnCardSelectedCallback {
    
    fileprivate let inviteButton = UIButton(type:.system)
    fileprivate var thread:CachedThread!
    fileprivate var mycid:String!
    fileprivate var mynickname:String!
    
    fileprivate var doneButton:UIBarButtonItem!
    
    fileprivate var closeContacts = [ChatContact]()
    fileprivate var closeContactsSelected:[Bool]?
    fileprivate var allContacts = [ChatContact]()
    fileprivate var allContactsSelected:[Bool]?
    fileprivate var selectedContactCount = 0
    
    fileprivate var popularBotsBar:CardScrollerView<SmallCardView>!
    fileprivate let popularBotsViewCell = UITableViewCell()
    
    fileprivate var coachesBar:CardScrollerView<SmallCardView>!
    fileprivate let coachesViewCell = UITableViewCell()
    
    fileprivate let sendInvitationViewCell = UITableViewCell()
    
    fileprivate weak var addHandler:AddHandler!
    
    fileprivate var processingAdd = false
    
    class func showAddToChat(_ nav:UINavigationController, mycard:Card, thread:CachedThread, addHandler:AddHandler ) {
        let vc = AddToChatViewController()
        vc.mycid = mycard.cid!
        vc.mynickname = mycard.nickname!
        vc.thread = thread
        vc.addHandler = addHandler
        nav.pushViewController( vc, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        edgesForExtendedLayout = UIRectEdge()
        
        doneButton = UIBarButtonItem(title: "Done (Button)".localized, style:.plain, target: self, action: #selector(doneButtonAction))
        doneButton.isEnabled = false    // enable after they click some people
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.title = "Add Into Chat (Title)".localized
        
        tableView.register(UINib(nibName: "RecentChatCardTableViewCell", bundle: nil), forCellReuseIdentifier: RecentChatCardTableViewCell.TABLE_CELL_IDENTIFIER)
        tableView.backgroundColor = UIConstants.LightGrayBackground
        tableView.separatorStyle = .none
        
        // setup bot whobar
        popularBotsBar = CardScrollerView<SmallCardView>(frame: CGRect( x:0, y:0, width:UIScreen.main.bounds.width, height:SmallCardView.Constants.Height ) )
        popularBotsViewCell.contentView.addSubview(popularBotsBar)
        popularBotsBar.cardSelectedCallback = self
        PopularBotCardsModel.instance.fetchCards {
            failure, cards in
            
            if let cards = cards {
                self.popularBotsBar.setCards(cards, tid:nil)
            }
        }
        
        // setup coach whobar
        coachesBar = CardScrollerView<SmallCardView>(frame: CGRect( x:0, y:0, width:UIScreen.main.bounds.width, height:SmallCardView.Constants.Height ) )
        coachesViewCell.contentView.addSubview(coachesBar)
        coachesBar.cardSelectedCallback = self
        CoachCardsModel.instance.fetchCards {
            failure, cards in
            
            if let cards = cards {
                self.coachesBar.setCards(cards, tid:nil)
            }
        }
        
        // button to send invitations
        inviteButton.frame = CGRect( x:0, y:0, width: UIScreen.main.bounds.width, height:40 )
        inviteButton.setTitle("Send Invitation (Button)".localized, for: .normal)

        sendInvitationViewCell.contentView.addSubview(inviteButton)
        sendInvitationViewCell.contentView.isUserInteractionEnabled = false

        RecentChatContactsFinder.findContacts(mycid) {
            closeContacts, allContacts in
            self.closeContacts = closeContacts
            self.closeContactsSelected = [Bool](repeating:false, count:closeContacts.count)
            self.allContacts = allContacts
            self.allContactsSelected = [Bool](repeating:false, count:allContacts.count)
            tableView.reloadData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .addToChat, vc:self )
    }
    
    func doneButtonAction() {
        addHandler.addContacts(self, contactList: selectedContacts() ) {
            success in
            if success {
                self.unwind()
            }
        }
    }
    
    fileprivate func unwind() {
        _ = navigationController?.popViewController(animated: true)
    }
    
    func onCardSelected(_ sender:NSObject, card:Card, color:UIColor) {
        if processingAdd {
            return
        }
        processingAdd = true
        
        if sender == popularBotsBar {
            addHandler.addBot(self, botcard:card ) {
                success in
                self.processingAdd = false
                if success {
                    self.unwind()
                }
            }
        } else if sender == coachesBar {
            addHandler.addCoach(self, cid:card.cid! ) {
                success in
                self.processingAdd = false
                if success {
                    self.unwind()
                }
            }
        }
    }
    
    // Handle selecting contacts
    
    fileprivate func toggleSelectedPerson(_ indexPath: IndexPath) {
        if let cell = tableView.cellForRow( at: indexPath ) {
            if cell.accessoryType == .checkmark {
                selectedContactCount -= 1
                cell.accessoryType = .none
                updateDone(false, indexPath:indexPath )
            } else {
                if selectedContactCount >= 10 {
                    warnMaxAddsExceeded()
                } else {
                    selectedContactCount += 1
                    cell.accessoryType = .checkmark
                    updateDone(true, indexPath:indexPath )
                }
            }
        }
    }
    
    fileprivate func warnMaxAddsExceeded() {
        AlertHelper.showOkAlert(self, title: "Max Contacts Reached (Title)".localized, message: "You only add 10 people at a time".localized, okAction: nil)
    }
    
    fileprivate func updateDone(_ selected:Bool, indexPath: IndexPath) {
        if indexPath.section == 3 {
            closeContactsSelected?[indexPath.row] = selected
        } else {
            allContactsSelected?[indexPath.row] = selected
        }
        
        doneButton.isEnabled = closeContactsSelected?.index(of:true) != nil || allContactsSelected?.index(of:true) != nil
    }
    
    fileprivate func selectedContacts() -> [ChatContact] {
        var contacts = [ChatContact]()
        
        for (i,selected) in closeContactsSelected!.enumerated() {
            if selected {
                contacts.append( closeContacts[i] )
            }
        }
        
        for (i,selected) in allContactsSelected!.enumerated() {
            if selected {
                let contact = allContacts[i]
                if does(contacts,haveCid:contact.cid!) == false {    // eliminate duplicates
                    contacts.append( contact )
                }
            }
        }
        
        return contacts
    }
    
    fileprivate func does(_ list:[ChatContact], haveCid cid:String) -> Bool {
        for contact in list {
            if contact.cid == cid {
                return true
            }
        }
        
        return false
    }
    
    //
    // MARK: Section handling
    //
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat{
        switch indexPath.section {
        case 0:
            return SmallCardView.Constants.Height   // bots
        case 1:
            return SmallCardView.Constants.Height   // coaches
        case 2:
            return sendInvitationViewCell.frame.height
        case 3:
            return RecentChatCardTableViewCell.Constants.Height
        case 4:
            return RecentChatCardTableViewCell.Constants.Height
        default:
            return 40.0 // wha?!
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            break
        case 1:
            break
        case 2:
            if processingAdd {
                return
            }
            processingAdd = true
            InviteHelper.start( self, mycid:mycid, thread:thread, inviteButton:inviteButton ) {
                self.processingAdd = false
            }
        case 3:
            toggleSelectedPerson(indexPath)
        case 4:
            toggleSelectedPerson(indexPath)
        default:
            break // wha?!
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        switch section {
        case 0:
            return "Popular Bots (Section)".localized
        case 1:
            return "A Coach To Help Learn Mobido (Section)".localized
        case 2:
            return "People You Know Outside Mobido (Section)".localized
        case 3:
            return String( format:"People %@ Has Chatted With (Section)".localized, mynickname )
        case 4:
            return "All People You Have Chatted With (Section)".localized
        default:
            return "Error!"
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 1
        case 2:
            return 1
        case 3:
            return closeContacts.count
        case 4:
            return allContacts.count
        default:
            return 0    // wha?!
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            return popularBotsViewCell
        case 1:
            return coachesViewCell
        case 2:
            return sendInvitationViewCell
        case 3:
            return recycleCell(indexPath)
        case 4:
            return recycleCell(indexPath)
        default:
            print( "ERROR AddToChatViewController().tableView:cellForRow" )
            return UITableViewCell()
        }
    }
    
    fileprivate func recycleCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RecentChatCardTableViewCell.TABLE_CELL_IDENTIFIER, for: indexPath) as! RecentChatCardTableViewCell
        
        let contact = indexPath.section == 3 ? closeContacts[indexPath.row] : allContacts[indexPath.row]
        cell.refresh( contact )
        
        let selected = indexPath.section == 3 ? closeContactsSelected![indexPath.row] : allContactsSelected![indexPath.row]
        cell.accessoryType = selected ? .checkmark : .none
        
        return cell
    }
}
