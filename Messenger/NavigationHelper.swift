import Foundation

class NavigationHelper {
    
    // figure out if need to show() or present() the view
    class func show<T: UIViewController>( _ vc:UIViewController, storyboard:String, id:String ) -> (vc:T,unwinder:()->Void) {
        if let nav = vc.navigationController {
            return (NavigationHelper.push(nav, storyboard:storyboard, id:id ),{nav.popViewController(animated: true)})
        } else {
            let target:T = NavigationHelper.present(vc, storyboard:storyboard, id:id )
            return (target,{target.dismiss(animated: true, completion: nil)})
        }
    }
    
    // use push() when I have a navigation controller
    // use pop to exit
    @discardableResult class func push<T: UIViewController>(_ nav:UINavigationController, storyboard:String, id:String ) -> T {
        
        let storyboard = UIStoryboard(name: storyboard, bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: id) as! T
        
        nav.pushViewController(vc, animated: true)
        
        return vc
    }
    
    // use present() when I dont have a navigation controller
    // use dismiss to exit
    class func present<T: UIViewController>(_ vc:UIViewController, storyboard:String, id:String ) -> T {
        
        let storyboard: UIStoryboard = UIStoryboard(name: storyboard, bundle: nil)
        let target = storyboard.instantiateViewController(withIdentifier: id) as! T
        
        // wrap in navigation controller
        let nav = UINavigationController(rootViewController: target)
        vc.present(nav, animated: true ) {
            nav.title = target.title
            target.navigationItem.leftBarButtonItem = UIBarButtonItem( title: "Back".localized, style: .plain, target:target, action: Selector(("leftButtonAction:")) )
        }
        
        return target
    }
    
    /*
    class func rootView(_ segue: UIStoryboardSegue) -> UIViewController {
        let vc = segue.destination
        if let nav = vc as? UINavigationController {
            let root = nav.viewControllers.first
            return root!
        } else {
            return vc
        }
    }*/
    
    class func findViewController( _ view:UIView ) -> UIViewController? {
        var i:UIResponder = view
        while true {
            if let vc = i as? UIViewController {
                return vc
            }
            guard let r = i.next else {
                return nil
            }
            
            i = r
        }
    }
    
    class func fadeInNewRootVC(_ vc:UIViewController) {
        let frame = UIScreen.main.bounds
        let overlayView = UIView(frame: frame)
        overlayView.backgroundColor = UIColor.white

        UIApplication.shared.keyWindow?.rootViewController = vc
        vc.view.addSubview( overlayView )
        
        UIView.animate(withDuration: 0.4, delay:0.0, options: UIViewAnimationOptions.transitionCrossDissolve, animations: {
            overlayView.alpha = 0
            }, completion: { finished in
                overlayView.removeFromSuperview()
        })
    }
}
