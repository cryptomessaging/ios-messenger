//
//  MainViewController.swift
//  Messenger
//
//  Created by Mike Prince on 11/25/15.
//  Copyright © 2015 Mike Prince. All rights reserved.
//

import UIKit
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class MainViewController: UITabBarController, UITabBarControllerDelegate {
    
    fileprivate let myCards = MyCardsModel.instance
    fileprivate let threadHistory = ThreadHistoryModel.instance
    fileprivate let popularBotCardsModel = PopularBotCardsModel.instance
    fileprivate let recommendedBotCardsModel = RecommendedBotCardsModel.instance
    fileprivate let coachCardsModel = CoachCardsModel.instance
    
    class func create() -> UIViewController {
        let vc = MainViewController()
        return vc
    }
    
    class func showMain() {
        NavigationHelper.fadeInNewRootVC( create() )
    }
    
    /*
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
    }*/

    override func viewDidLoad() {
        super.viewDidLoad()
        
        PushRegistration.instance.register()
        
        let homeBotVC = HomeBotViewController.createViewController()
        homeBotVC.tabBarItem = UITabBarItem(title: "Mobido HomeBot (Tab)".localized, image: UIImage(named: "Home"), selectedImage: UIImage(named: "Home"))
        
        let threadsVC = ThreadHistoryViewController.createThreadHistory()
        threadsVC.tabBarItem = UITabBarItem(title: "Thread History (Tab)".localized, image: UIImage(named: "Chat History"), selectedImage: UIImage(named: "Chat History"))
        
        let mycardsVC = MyCardListViewController.createMyCardListViewController()
        mycardsVC.tabBarItem = UITabBarItem(title: "My Cards (Tab)".localized, image: UIImage(named: "My Cards"), selectedImage: UIImage(named: "My Cards"))
        
        /*let kidVC = KidListViewController.createKidListViewController()
        kidVC.tabBarItem = UITabBarItem(title: "Kid List (Tab)".localized, image: UIImage(named: "Kids"), selectedImage: UIImage(named: "Kids"))*/
        
        let moreVC = MoreViewController.createMoreViewController()
        moreVC.tabBarItem = UITabBarItem(title: "Settings (Tab)".localized, image: UIImage(named: "More"), selectedImage: UIImage(named: "More"))
        
        let controllers = [homeBotVC, threadsVC, mycardsVC, /*kidVC,*/ moreVC]
        self.viewControllers = controllers

        delegate = self
        NotificationHelper.addObserver(self, selector: #selector(onNoCards), name: .noCards)
        NotificationHelper.addObserver(self, selector: #selector(onShowChat), name: .showChat)
    }
    
    deinit {
        NotificationHelper.removeObserver(self)
    }
    
    let THREAD_INDEX = 1
    let MYCARDS_INDEX = 2
    
    // user has no cards
    func onNoCards() {
        // filter PII?
        //let filterPII = AccessKeyHelper.checkPIIFilter()
        // if filterPII == false || ...
        if UIConstants.requireNewUserCard && MyUserDefaults.instance.check( .WasQuickstartOffered ) {
            // Show "my cards" which will prompt to create a new card
            tabBarController(self, shouldSelect: self.viewControllers![MYCARDS_INDEX] ) {}
        } else if UIConstants.offerQuickstart {
            // remember that the quickstart was offered, so it's not offered again
            MyUserDefaults.instance.set( .WasQuickstartOffered, value:true )
            QuickstartViewController.presentQuickstart(self)
        }
    }
    
    func onShowChat( _ notification: Notification ) {
        if let userInfo = notification.userInfo {
            if let tid = userInfo["tid"] as! String? {
                // Move bottom app tab to chats (second tab, index 1), causes animation
                let nav = viewControllers![THREAD_INDEX] as! UINavigationController
                tabBarController(self, shouldSelect: nav ) {
                    // remove any windows they were down in BEFORE animation to slide in chats
                    nav.popToRootViewController(animated: false)
                    
                    // Tell thread history view controller to show this thread
                    if let vc = nav.viewControllers.first as? ThreadHistoryViewController {
                        vc.showThread( tid )
                    } else {
                        DebugLogger.instance.append(function: "onShowChat", message:"Failed showing thread" )
                    }
                }
                
                return
            }
        }
        
        print( "ERROR: Failed to handle notification \(notification)")
    }
    
    fileprivate func tabBarController(_ tabBarController: UITabBarController, shouldSelect toVC: UIViewController, completion: @escaping () -> () ) {
        
        // http://stackoverflow.com/questions/5161730/iphone-how-to-switch-tabs-with-an-animation
        let toIndex = self.viewControllers!.index( of: toVC )!
        if toIndex == tabBarController.selectedIndex {
            completion()    // already there!
            return
        }
    
        // Get the views.
        let currentVC = tabBarController.selectedViewController
        if currentVC == nil {
            // weird... no "from" found, so just jump straight to next tab
            tabBarController.selectedIndex = toIndex
            completion()
            return
        }
        let fromView = currentVC!.view
        let toView = toVC.view
    
        // Get the size of the view area.
        let viewSize = fromView?.frame
        let scrollRight = toIndex > tabBarController.selectedIndex
    
        // Add the to view to the tab bar view.
        fromView?.superview!.addSubview( toView! )
    
        // Position it off screen.
        let screenWidth = UIScreen.main.bounds.size.width
        toView?.frame = CGRect(x: (scrollRight ? screenWidth : -screenWidth), y: (viewSize?.origin.y)!, width: screenWidth, height: (viewSize?.size.height)!)
    
        UIView.animate( withDuration: 0.2, delay:0, options:UIViewAnimationOptions(), animations: {
            // Animate the views on and off the screen. This will appear to slide.
            fromView?.frame = CGRect(x: (scrollRight ? -screenWidth : screenWidth), y: (viewSize?.origin.y)!, width: screenWidth, height: (viewSize?.size.height)!)
            toView?.frame = CGRect(x: 0, y: (viewSize?.origin.y)!, width: screenWidth, height: (viewSize?.size.height)!)
        } ) {
            finished in
            
            if finished {
                // Remove the old view from the tabbar view.
                fromView?.removeFromSuperview()
                tabBarController.selectedIndex = toIndex
                
                completion()
            }
        }
    }
}
