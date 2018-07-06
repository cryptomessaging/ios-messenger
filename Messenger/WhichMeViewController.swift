import UIKit

open class WhichMeViewController : PopoverViewController {

    fileprivate var cards:[Card]!
    fileprivate var selectedCard:Card?
    fileprivate var offerCreate:Bool!
    fileprivate var popoverTitle:String!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var coverImage: UIImageView!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var cardRow: UIStackView!
    @IBOutlet weak var buttonRow: UIStackView!
    
    var createButton: UIButton!
    
    fileprivate var cardSelectedCallback:((_ card:Card?)->Void)!
    
    class func showWhichMePopover(_ parent:UIViewController, cards:[Card], title:String, offerCreate:Bool, cardSelectedCallback:@escaping (_ card:Card?)->Void ) {
        let popover = WhichMeViewController(nibName: "WhichMeView", bundle: nil)
        popover.cards = cards
        popover.cardSelectedCallback = cardSelectedCallback
        popover.popoverTitle = title
        popover.offerCreate = offerCreate
        showPopover(parent, popover:popover )
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = popoverTitle
        ImageHelper.round( coverImage )
        setMyCard( cards.first! )
        
        let recognizer = UITapGestureRecognizer(target:self, action: #selector(changeCardAction) )
        cardRow.isUserInteractionEnabled = true
        cardRow.addGestureRecognizer(recognizer)
        
        if offerCreate {
            let titleColor = cancelButton.titleColor(for: .normal)
            
            createButton = UIButton(frame:CGRect.zero)
            createButton.backgroundColor = UIColor.clear
            createButton.setTitle("Create (Button)".localized, for: .normal )
            createButton.setTitleColor(titleColor, for: .normal)
            createButton.addTarget(self, action: #selector(createCardAction), for: UIControlEvents.touchUpInside)
            
            buttonRow.insertArrangedSubview( createButton, at: 1 )    // second/middle position
            createButton.widthAnchor.constraint(equalTo:cancelButton.widthAnchor).isActive = true

            messageLabel.text = "Select a persona or create a new one".localized
        } else {
            messageLabel.text = "Select a persona".localized
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .whichMe, vc:self )
    }
    
    func setMyCard( _ card:Card ) {
        selectedCard = card
        nicknameLabel.text = card.nickname
        ImageHelper.fetchCardCoverImage(card.cid!, ofSize: UIConstants.CardCoverSize, forImageView: coverImage!)
    }
    
    func changeCardAction(_ sender: UIButton) {
        MyCardChooserViewController.showCardChooser(self,cards:cards) {
            card in
            self.setMyCard(card)
        }
    }
    
    func createCardAction(_ sender: UIButton) {
        EditCardViewController.showCreateCard(self.navigationController!) {
            card in
            
            if let card = card {
                self.dismiss(animated: true, completion: nil)
                self.cardSelectedCallback(card)
            }
        }
    }
    
    override func okButtonAction(_ sender: UIButton!) {
        dismiss(animated: true, completion: nil)
        cardSelectedCallback(selectedCard!)
    }
    
    override func cancelButtonAction(_ sender: UIButton!) {
        dismiss(animated: true, completion: nil)
        cardSelectedCallback(nil)
    }
}
