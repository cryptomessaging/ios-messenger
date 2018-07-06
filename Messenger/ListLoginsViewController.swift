//
//  ListLoginsViewController.swift
//  Messenger
//
//  Created by Mike Prince on 2/19/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class ListLoginsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()
    fileprivate var logins:[LoginState]!
    
    fileprivate var addLoginButton:UIBarButtonItem!
    fileprivate var syncButton:UIBarButtonItem!
    fileprivate var refreshOnReappearance = false
    
    class func showLoginList(_ nav:UINavigationController) {
        let vc = ListLoginsViewController()
        nav.pushViewController(vc, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup navigation bar
        syncButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(syncAction))
        addLoginButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addLoginAction))
        navigationItem.rightBarButtonItems = [ syncButton, addLoginButton ]
        navigationItem.title = "Login List (Title)".localized
        
        // setup tableview
        tableView.frame = view.frame
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        view.addSubview( tableView )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if logins == nil || refreshOnReappearance {
            reload()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .listLogins, vc:self )
    }
    
    func addLoginAction(_ sender: UIBarButtonItem) {
        refreshOnReappearance = true
        AddLoginViewController.showAddLogin(self.navigationController!)
    }
    
    func syncAction(_ sender: UIBarButtonItem) {
        reload()
    }
    
    func reload() {
        syncButton.isEnabled = false
        let progress = ProgressIndicator(parent: view, message: "Loading Logins (Progress)".localized )
        MobidoRestClient.instance.fetchMyLogins {
            result in
            progress.stop()
            self.syncButton.isEnabled = true
            
            if ProblemHelper.showProblem(self, title: "Problem Loading Logins (Title)".localized, failure: result.failure ) {
                return
            }
            
            UIHelper.onMainThread {
                self.logins = result.logins!
                self.tableView.reloadData()
                self.refreshOnReappearance = false
            };
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let logins = logins {
            return logins.count
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
        
        let login = logins[indexPath.row]
        cell.textLabel?.text = login.id
        
        // craft a good description
        var detail = ""
        if login.owned != nil && login.owned! {
            detail += "Ready to login".localized
        } else {
            detail += "Cannot login yet".localized
        }
        
        if login.authority != "email" {
            
        } else if login.verified != nil && login.verified! {
            detail += " - Email verified".localized
        } else {
            detail += " - Email not verified".localized
        }
        cell.detailTextLabel?.text = detail
        
        return cell
    }
    
    enum UpdateType: String {
        case DELETE
        case RESEND_VERIFICATION
    }
    
    static let EMAIL_UPDATE_LIST:[KeyedLabel] = [KeyedLabel(key:UpdateType.DELETE.rawValue,label:"Delete (List Option)".localized),
                                  KeyedLabel(key:UpdateType.RESEND_VERIFICATION.rawValue,label:"Resend Verification Email (List Option)".localized)]
    static let USERNAME_UPDATE_LIST:[KeyedLabel] = [KeyedLabel(key:UpdateType.DELETE.rawValue,label:"Delete (List Option)".localized)]

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let login = logins[indexPath.row]
        let items = login.authority == "email" ? ListLoginsViewController.EMAIL_UPDATE_LIST : ListLoginsViewController.USERNAME_UPDATE_LIST
        
        let options = ListPickerOptions()
        options.screenName = .updateLogin
        options.result = .loginUpdated
        options.selected = MyUserDefaults.instance.getTheme()
        options.defaultAccessoryType = .disclosureIndicator
        ListPickerViewController.showPicker(self.navigationController!, title:login.id!, items:items, options:options ) {
            result in
            
            if result.key == UpdateType.DELETE.rawValue {
                self.confirmDelete( indexPath )
            } else {
                self.resendEmailVerification(Login(authority: login.authority!,id: login.id!))
            }
        }
    }
    
    func confirmDelete(_ indexPath: IndexPath) {
        // don't allow last login to be deleted
        if logins.count < 2 {
            AlertHelper.showAlert(self, title:"Cannot Delete (Title)".localized, message:"You must have at least one login".localized, okStyle: UIAlertActionStyle.default, okAction:nil )
            return
        }
        
        let login = self.logins[indexPath.row]
        let message = String(format: "You will no longer be able to login as %@".localized, login.id! )
        AlertHelper.showAlert(self, title:"Delete Login? (Title)".localized, message:message, okStyle: UIAlertActionStyle.destructive ) {
            self.deleteLogin( indexPath.row, login:Login(authority: login.authority!,id: login.id!) )
        }
    }
    
    func deleteLogin(_ row:Int, login:Login) {
        let progress = ProgressIndicator(parent: self.view, message: "Deleting Login (Progress)".localized )
        
        MobidoRestClient.instance.deleteLogin( login ) {
            result in
            
            progress.stop()
            if !ProblemHelper.showProblem(self, title: "Problem Deleting Login (Title)".localized, failure: result.failure ) {
                self.logins.remove(at: row)
                self.reload()
            }
        }
    }
    
    func resendEmailVerification(_ login:Login) {
        let progress = ProgressIndicator(parent: self.view, message: "Resending Verification Email (Progress)".localized )
        //createButton?.enabled = false
        MobidoRestClient.instance.createLogin(login) {
            result -> Void in
            UIHelper.onMainThread {
                progress.stop()
                //self.createButton?.enabled = true
                
                if !ProblemHelper.showProblem(self, title: "Problem Resending Verification (Title)".localized, failure: result.failure ) {
                    //self.navigationController?.popViewControllerAnimated( true )
                }
            }
        }
    }
}
