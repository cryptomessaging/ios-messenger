import UIKit
import EasyTipView

class EditCardViewController : UIViewController, UITextFieldDelegate, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate /*, EasyTipViewDelegate */, UIGestureRecognizerDelegate {
    
    static let DEBUG = false
    
    fileprivate var card:Card?
    fileprivate var cardImage:UIImage?
    
    fileprivate var pictureTip:EasyTipView?
    
    @IBOutlet weak var cardCanvas: UIView!
    @IBOutlet weak var coverImage: UIImageView!
    @IBOutlet weak var nicknameField: UITextField!
    @IBOutlet weak var taglineView: UITextView!
    @IBOutlet weak var reputationTable: UITableView!

    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var navigationBar: UINavigationItem!
    
    fileprivate var tapRecognizer:UITapGestureRecognizer!
    fileprivate let cameraController = UIImagePickerController()
    fileprivate var longPressRecognizer:UILongPressGestureRecognizer!
    fileprivate let photoPickerController = UIImagePickerController()
    
    fileprivate var doFilterPII = false  // optimist, but check accessKey.acm
    fileprivate var hasNewImage = false
    
    fileprivate var completion:((Card?)->Void)?
    
    static let TaglinePlaceholder = "A few words about yourself".localized
    
    class func showCreateCard(_ parent:UIViewController, completion: ((Card?)->Void)? ) {
        let vc = EditCardViewController(nibName: "EditCardView", bundle: nil)
        vc.completion = completion
        parent.present(vc, animated: true, completion: nil )
    }
    
    class func showEditCard(_ parent:UIViewController, card: Card) {
        let vc = EditCardViewController(nibName: "EditCardView", bundle: nil)
        vc.card = card
        parent.present(vc, animated: true, completion: nil )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        edgesForExtendedLayout = UIRectEdge()
        
        if isNewCard() {
            navigationBar.title = "New Card (Title)".localized
            navigationBar.rightBarButtonItem?.title = "Create Card (Button)".localized
        }
        
        // setup camera
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            cameraController.sourceType = .camera
            cameraController.cameraCaptureMode = .photo
        } else {
            cameraController.sourceType = .photoLibrary
        }
        cameraController.modalPresentationStyle = .overCurrentContext
        cameraController.delegate = self
        
        // setup photo picker (long press)
        photoPickerController.sourceType = .photoLibrary
        photoPickerController.modalPresentationStyle = .overCurrentContext
        photoPickerController.delegate = self
        
        nicknameField.delegate=self
        nicknameField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
        nicknameField.autocapitalizationType = .words
        
        taglineView.autocapitalizationType = .sentences
        taglineView.delegate = self
        setTaglinePlaceholder()
        
        ImageHelper.round(coverImage, radius:25)
        
        if let card = card {
            nicknameField.text = card.nickname
            taglineView.text = card.tagline
            ImageHelper.fetchCardCoverImage(card.cid!, ofSize:UIConstants.CardCoverSize, forImageView: coverImage)
        }
        
        view.backgroundColor = UIConstants.LightGrayBackground
        checkValidFields()
        
        // set reputation table height
        let constraint = NSLayoutConstraint(item: reputationTable, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 0)
        view.addConstraint( constraint )
        
        // handle taps and long presses on cover image
        coverImage.isUserInteractionEnabled = true
        tapRecognizer = UITapGestureRecognizer(target: self, action:#selector(selectImage))
        tapRecognizer.numberOfTapsRequired = 1
        coverImage.addGestureRecognizer(tapRecognizer)
        longPressRecognizer = UILongPressGestureRecognizer(target:self, action:#selector(selectImage))
        coverImage.addGestureRecognizer(longPressRecognizer)
        
        // filter PII?
        if let ak = MyUserDefaults.instance.getAccessKey(), let acm = ak.acm {
            doFilterPII = acm["pii"] == "filter"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( isNewCard() ? .createCard : .editCard, vc:self )
    }
    
    fileprivate func isNewCard() -> Bool {
        return card == nil || card!.cid == nil
    }
    
    //
    // MARK: Validate fields
    //
    
    func textFieldDidEndEditing( _ textField: UITextField) {
        NicknameHelper.alertIfNicknameInvalid(self,nickname: nicknameField.text,doFilterPII: doFilterPII)
    }
    
    func textFieldDidChange(_ textField:UITextField) {
        checkValidFields()
    }
    
    func checkValidFields() {
        let nickname = StringHelper.clean(nicknameField.text)
        if nickname == nil {
            saveButton.isEnabled = false
            return
        }
        
        if doFilterPII && StringHelper.countWords(nickname!) > 1 {
            saveButton.isEnabled = false
        } else {
            saveButton.isEnabled = true
        }
    }
    
    //
    // MARK: Next responder after "returns"
    //
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if !NicknameHelper.alertIfNicknameInvalid(self,nickname: nicknameField.text,doFilterPII: doFilterPII) {
            return false
        }
        
        textField.resignFirstResponder()
        taglineView.becomeFirstResponder()
        
        return false
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            taglineView.resignFirstResponder()
            
            if cardImage == nil {
                showPictureTip()
            }
            
            return false
        } else {
            return true
        }
    }
    
    func easyTipViewDidDismiss(_ tipView : EasyTipView) {
        pictureTip = nil
    }
    
    fileprivate func showPictureTip() {
        if pictureTip != nil {
            return
        }
        
        if doFilterPII {
            // not allowed to take pictures yet, so don't recommend
            return
        }
        
        pictureTip = EasyTipView(text:"Click here to take card picture".localized)
        pictureTip?.show(forView: coverImage, withinSuperview: view)

        /*pictureTip = EasyTipView.show(animated: true,
                                        forView: coverImage,
                                        withinSuperview: self.view,
                                        text: "Click here to take card picture".localized )*/
    }
    
    //
    // MARK: Placeholder hacks
    //
    
    func textViewDidBeginEditing( _ textView: UITextView) {
        if taglineView.text == EditCardViewController.TaglinePlaceholder {
            taglineView.text = ""
            taglineView.textColor = UIColor.black
        }
    }
    
    func textViewDidEndEditing( _ textView: UITextView) {
        if StringHelper.clean( taglineView.text ) == nil {
            setTaglinePlaceholder()
        }
    }

    fileprivate func setTaglinePlaceholder() {
        taglineView.text = EditCardViewController.TaglinePlaceholder
        taglineView.textColor = UIColor.gray
    }
    
    //
    // MARK: Navigation
    //
    
    @IBAction func cancelAction(_ sender: UIBarButtonItem) {
        //navigationController?.popViewControllerAnimated(true)
        dismiss(animated: true, completion: nil)
        completion?(nil)
    }
    
    @IBAction func saveAction(_ sender: UIBarButtonItem) {
        // make sure values from form are in card object
        populateCard()
        
        // create or update?
        if isNewCard() {
            createCard()
        } else {
            updateCard()
        }
    }
    
    @IBAction func showInformationPractices(_ sender: AnyObject) {
        let apiServer = MyUserDefaults.instance.getMobidoApiServer();
        let url = URL(string:"legal/information-practices.html", relativeTo: URL(string:apiServer) )
        WebViewController.showWebView(self, url:url!, title:"Information Practices (Title)".localized, screenName: .informationPractices )
    }
    
    // MARK: Actions
    
    @IBAction func selectImage(_ sender: UIGestureRecognizer) {
        
        if doFilterPII {
            AlertHelper.showOkAlert(self, title: "No Pictures Allowed (Alert Title)".localized, message: "We cannot allow pictures until your parent signs the consent form".localized, okAction: nil)
            return
        }

        nicknameField.resignFirstResponder()
        taglineView.resignFirstResponder()
        pictureTip?.dismiss()
        pictureTip = nil
        
        if sender == tapRecognizer {
            if EditCardViewController.DEBUG { print("Presenting camera controller") }
            present(cameraController, animated: true, completion: nil )
        } else if sender == longPressRecognizer && longPressRecognizer.state == .ended {
            if EditCardViewController.DEBUG { print("Presenting photo picker controller") }
            present(photoPickerController, animated: true, completion: nil )
        }
    }
    
    //
    // MARK: UIImagePickerControllerDelegate
    //
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        // use same 'image' var so garbage collection can happen if it needs
        var image = info[UIImagePickerControllerOriginalImage] as! UIImage
        
        image = ImageHelper.resizeImage(image,minSide:1000)
        image = ImageHelper.cropImage(image)
        
        coverImage.image = image
        cardImage = image
        hasNewImage = true
        
        checkValidFields()
        dismiss(animated: true, completion: nil)
    }
    
    //
    // MARK: Create/update card to server
    //
    
    fileprivate func populateCard() {
        if card == nil {
            card = Card()
        }
        
        card!.nickname = StringHelper.clean( nicknameField.text)
        card!.created = TimeHelper.nowAs8601()
        
        card!.tagline = nil
        if let tagline = StringHelper.clean( taglineView.text ) {
            if tagline != EditCardViewController.TaglinePlaceholder {
                card!.tagline = tagline
            }
        }
    }
    
    fileprivate func base64image() -> String {
        if hasNewImage {
            let jpeg = UIImageJPEGRepresentation(coverImage.image!, 1.0 )
            return jpeg!.base64EncodedString(options: NSData.Base64EncodingOptions.lineLength76Characters)
        } else {
            // use zero length image to imply none
            return ImageHelper.ZERO_LENGTH_BASE64 
        }
    }
    
    fileprivate func createCard() {
        let progress = ProgressIndicator(parent:view, message:"Saving".localized)
        saveButton.isEnabled = false
        
        let base64 = base64image()
        
        // craft new card
        let newCard = NewCard()
        newCard.nickname = card!.nickname
        newCard.tagline = card!.tagline
        newCard.media = ImageHelper.toDataUri( base64 )
        
        let progressHandler: (Int64, Int64) -> () = {
            totalSent, uploadSize in
            
            let percent = Int( Float(totalSent) / Float(uploadSize) * 100 )
            let msg = String( format:"Saving %d".localized, percent )
            progress.onStatus( msg )
        }
        
        MobidoRestClient.instance.createCard(newCard, progressHandler:progressHandler ) {
            result in
            
            // if successful, add to my local cache
            if result.failure == nil, let cid = result.cid {
                self.card!.cid = cid
                MyCardsModel.instance.updateMyCardInCache(self.card!, flushMedia: false)
            }
            
            DispatchQueue.main.async(execute: {
                progress.stop()
                AnalyticsHelper.trackResult(.cardCreated)
                
                self.saveButton.isEnabled = true
                self.handleNewCardResult( result )
            })
        }
    }
    
    // NOTE: make sure this only happens on the main thread
    fileprivate func handleNewCardResult( _ result:NewCardResult!) {
        if let failure = result.failure {
            ProblemHelper.showProblem(self, title: "Problem saving card".localized, failure: failure )
        } else {
            card!.cid = result.cid!
            dismiss(animated: true)
            self.completion?(self.card)
        }
    }
    
    fileprivate func updateCard() {
        let progress = ProgressIndicator(parent:view, message:"Saving".localized )
        saveButton.isEnabled = false
        
        // craft new card
        let cardUpdates = CardUpdates()
        cardUpdates.cid = card!.cid
        cardUpdates.nickname = card!.nickname
        cardUpdates.tagline = card!.tagline
        cardUpdates.rids = card!.rids
        
        // new image?
        if hasNewImage {
            let base64 = base64image()
            cardUpdates.media = "data:image/jpeg;base64,\(base64)"
        }
        
        let progressHandler: ( Int64,  Int64) -> () = {
            totalSent, uploadSize in
            
            let percent = Int( Float(totalSent) / Float(uploadSize) * 100 )
            let msg = String( format:"Saving %d".localized, percent )
            progress.onStatus( msg )
        }
        
        MobidoRestClient.instance.updateCard(cardUpdates, progressHandler:progressHandler ) {
            result in
            
            if result.failure == nil {
                MyCardsModel.instance.updateMyCardInCache(self.card!, flushMedia: self.hasNewImage)
            }
            
            DispatchQueue.main.async(execute: {
                progress.stop()
                AnalyticsHelper.trackResult(.cardUpdated)
                
                self.saveButton.isEnabled = true
                self.handleUpdateCardResult( result )
            })
        }
    }
    
    // NOTE: make sure this only happens on the main thread
    fileprivate func handleUpdateCardResult( _ result:BaseResult!) {
        if let failure = result.failure {
            ProblemHelper.showProblem(self, title: "Problem updating card".localized, failure: failure )
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
}
