//
//  KidsViewController.swift
//  Messenger
//
//  Created by Mike Prince on 10/31/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import Foundation

class KidListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()
    fileprivate var kids:[MyChild]!
    
    fileprivate var addKidButton:UIBarButtonItem!
    fileprivate var syncButton:UIBarButtonItem!
    fileprivate var refreshOnReappearance = false
    fileprivate var longPressRecognizer:UILongPressGestureRecognizer!
    
    class func createKidListViewController() -> UIViewController {
        let vc = KidListViewController()
        vc.edgesForExtendedLayout = UIRectEdge()
        
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup navigation bar
        let navItem = UINavigationItem(title: "Kid List (Title)".localized);
        syncButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(syncAction))
        addKidButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addKidAction))
        navItem.rightBarButtonItems = [ syncButton, addKidButton ]
        
        let navBar = UINavigationBar(frame: CGRect( x: 0, y: 20, width: view.frame.size.width, height: 44 ) )
        view.addSubview(navBar);
        navBar.setItems([navItem], animated: false);
        
        // setup tableview
        tableView.frame = CGRect( x: 0, y: 65, width: view.frame.size.width, height: view.frame.size.height - 65 )
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        view.addSubview( tableView )
        
        // catch long press for delete
        longPressRecognizer = UILongPressGestureRecognizer( target:self, action: #selector(longPress))
        tableView.addGestureRecognizer( longPressRecognizer )
    }
    
    func addKidAction(_ sender: UIBarButtonItem) {
        refreshOnReappearance = true
        StartConsentViewController.presentStartConsent(self)
    }
    
    func syncAction(_ sender: UIBarButtonItem) {
        reload()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if kids == nil || refreshOnReappearance {
            reload()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .kidList, vc:self )
    }
    
    func reload() {
        syncButton.isEnabled = false
        let progress = ProgressIndicator(parent: view, message: "Finding children".localized )
        MobidoRestClient.instance.fetchMyChildren {
            result in
            progress.stop()
            self.syncButton.isEnabled = true
            
            if ProblemHelper.showProblem(self, title: "Problem loading children".localized, failure: result.failure ) {
                return
            }
            
            UIHelper.onMainThread {
                self.kids = result.children!
                self.tableView.reloadData()
            };
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let kids = kids {
            return kids.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell:UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier")
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "reuseIdentifier")
            cell.accessoryType = .disclosureIndicator
        }
        
        let child = kids[indexPath.row]
        cell.textLabel?.text = child.kidname
        
        // craft a good description
        var nextStep:String!
        if child.acmValue("coppa") == "notified" {
            nextStep = "Your consent (Next Step)".localized
        } else {
            nextStep = child.uid == nil ? "Create child account (Next Step)".localized : "Manage child (Next Step)".localized
        }
        
        let birthday = child.birthday != nil ? child.birthday : "unknown (Birthday)".localized
        
        let detail = String( format: "birthday:%@ next step:%@".localized, birthday!, nextStep )
        cell.detailTextLabel?.text = detail
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        refreshOnReappearance = true
        
        let child = kids[indexPath.row]
        /*let coppa = child.acmValue("coppa")
        if child.uid != nil && coppa == "verified" {
            KidDetailViewController.showKidDetail( self, child:child )
        } else {*/
            ConsentStatusViewController.showConsentStatus( self, child:child)
        //}
    }
    
    func longPress(_ sender: UILongPressGestureRecognizer) {
        if longPressRecognizer.state == UIGestureRecognizerState.began {
            let touchPoint = longPressRecognizer.location(in: self.tableView)
            if let indexPath = tableView.indexPathForRow(at: touchPoint) {
                let child = self.kids[indexPath.row]
                let message = String(format: "Remove %@ from your list of kids?  This does NOT delete their account.".localized, child.kidname! )
                AlertHelper.showAlert(self, title:"Delete Relationship? (Title)".localized, message:message, okStyle: UIAlertActionStyle.destructive ) {
                    self.unlinkChildAccount( child )
                }
            }
        }
    }
    
    func unlinkChildAccount(_ kid:MyChild) {
        let progress = ProgressIndicator(parent: self.view, message: "Removing Parent Relationship (Progress)".localized )
        
        let unlink = UnlinkChild()
        unlink.kidname = kid.kidname
        unlink.uid = kid.uid
        MobidoRestClient.instance.unlinkChildAccount( unlink ) {
            result in
            
            progress.stop()
            if ProblemHelper.showProblem(self, title: "Problem Removing Relationship (Alert Title)".localized, failure: result.failure ) {
                return
            }
            
            self.reload()
        }
    }
}
