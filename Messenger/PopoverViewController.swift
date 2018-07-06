import UIKit
import QuartzCore

class PresentationControllerDelegate : NSObject, UIPopoverPresentationControllerDelegate {
}

open class PopoverViewController : UIViewController {
    
    @IBOutlet weak var popUpView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var okButton: UIButton!
    
    class func showPopover(_ parent:UIViewController, popover:UIViewController ) {
        // make sure we have a navigation controller?
        if parent.navigationController == nil {
            let nav = UINavigationController(rootViewController: popover )
            nav.modalPresentationStyle = UIModalPresentationStyle.popover
            parent.present( nav, animated:true, completion:nil )
            ipadFixup( parent, popover:nav )
        } else {
            popover.modalPresentationStyle = UIModalPresentationStyle.popover
            parent.present( popover, animated:true, completion:nil )
            ipadFixup( parent, popover:popover )
        }
    }
    
    // configure the Popover presentation controller
    class func ipadFixup(_ parent:UIViewController, popover:UIViewController ) {
        if let controller = popover.popoverPresentationController {
            controller.permittedArrowDirections = UIPopoverArrowDirection.any
            controller.delegate = PresentationControllerDelegate()
            controller.sourceView = parent.view // where its anchored
            controller.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        }
    }
    
    //
    // MARK: Init
    //
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        let layer = self.popUpView.layer
        layer.cornerRadius = 8
        layer.shadowOpacity = 0.8
        layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        
        okButton.addTarget(self, action: #selector(okButtonAction), for: UIControlEvents.touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonAction), for: UIControlEvents.touchUpInside)
    }
    
    func okButtonAction(_ sender: UIButton!) {
        print("Override me!")
    }
    
    func cancelButtonAction(_ sender: UIButton!) {
        dismiss(animated: true, completion: nil)
    }
}
