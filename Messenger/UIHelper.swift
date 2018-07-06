import UIKit

protocol UIViewLoading {}
extension UIView : UIViewLoading {}

extension UIViewLoading where Self : UIView {
    
    // note that this method returns an instance of type `Self`, rather than UIView
    static func loadFromNib() -> Self {
        let nibName = "\(self)".characters.split{$0 == "."}.map(String.init).last!
        let nib = UINib(nibName: nibName, bundle: nil)
        
        return nib.instantiate(withOwner: self, options: nil).first as! Self
    }
}

class UIHelper {
    
    class func ipadFixup( _ alert:UIAlertController, sender:UITapGestureRecognizer, inView:UIView, cancelHandler:((UIAlertAction) -> Swift.Void)? = nil ) {
        // popoverPresentationController only seems available on iPad
        if let ppc = alert.popoverPresentationController {
            ppc.sourceView = inView
            if let frame = sender.view?.frame {
                ppc.sourceRect = frame
                print( "Yo \(inView.frame) and \(frame)" )
            } else {
                DebugLogger.instance.append(function: "ipadFixup", message: "Missing view!" )
            }
        } else {
            // tapping outside action sheet only works on iphone so we add this action... weird...
            alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: cancelHandler ))
        }
    }
    
    class func ipadFixup( _ alert:UIAlertController, view:UIView, cancelHandler:((UIAlertAction) -> Swift.Void)? = nil ) {
        // popoverPresentationController only seems available on iPad
        if let ppc = alert.popoverPresentationController {
            ppc.sourceView = view
            //let size = sender.frame.size
            ppc.sourceRect = view.frame
        } else {
            // tapping outside action sheet only works on iphone so we add this action... weird...
            alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: cancelHandler ))
        }
    }
    
    class func ipadFixup( _ alert:UIAlertController, atLocation point:CGPoint, inView:UIView, cancelHandler:((UIAlertAction) -> Swift.Void)? = nil ) {
        // popoverPresentationController only seems available on iPad
        if let ppc = alert.popoverPresentationController {
            ppc.sourceView = inView
            ppc.sourceRect = CGRect(x: point.x, y: point.y, width: 1, height: 1 )
        } else {
            // tapping outside action sheet only works on iphone so we add this action... weird...
            alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: cancelHandler ))
        }
    }
    
    class func ipadFixup( _ alert:UIAlertController, barButtonItem:UIBarButtonItem ) {
        // popoverPresentationController only seems available on iPad
        if let ppc = alert.popoverPresentationController {
            ppc.barButtonItem = barButtonItem
        } else {
            // tapping outside action sheet only works on iphone so we add this action... weird...
            alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil ))
        }
    }
    
    class func topVC() -> UIViewController? {
        if var topController = UIApplication.shared.keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            // topController should now be your topmost view controller
            return topController
        }
        
        return nil
    }
    
    class func grow( _ frame:CGRect, border:CGFloat ) -> CGRect {
        let origin = frame.origin
        let size = frame.size
        return CGRect(x: origin.x - border, y: origin.y - border, width: size.width + border * 2, height: size.height + border * 2 )
    }
    
    class func delay(_ delay:Double, closure:@escaping ()->()) {
        DispatchQueue.main.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
    }
    
    class func onMainThread( _ closure:@escaping ()->() ) {
        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async(execute: closure )
        }
    }
    
    // http://makeapppie.com/2014/10/08/swift-swift-using-uicolor-in-swift-part-2-making-a-color-palette-with-hsb/
    class func cardColor(_ index:Int, range:Int) -> UIColor {
        let adjustedRange = range < 4 ? 4 : range
        let hue = CGFloat(index) / CGFloat(adjustedRange)
        
        return UIColor(
            hue: hue,
            saturation: 1.0,
            brightness: 1.0,
            alpha: 1.0)
    }
    
    class func unwind( vc:UIViewController ) {
        if let nav = vc.navigationController {
            nav.popViewController(animated: true )
        } else {
            vc.dismiss(animated: true, completion: nil )
        }
    }
    
    class func navigationBarHeight( _ vc:UIViewController ) -> CGFloat {
        if let nav = vc.navigationController {
            return nav.navigationBar.frame.size.height
        } else {
            return 0
        }
    }
}
