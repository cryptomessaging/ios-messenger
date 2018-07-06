import UIKit
import QuartzCore

open class JoinThreadViewController : PopoverViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    
    @IBOutlet weak var cardRow: UIStackView!
    @IBOutlet weak var cardImage: UIImageView!
    @IBOutlet weak var cardNickname: UILabel!
    
    @IBOutlet weak var changeCardButton: UIButton!
    
    fileprivate var rsvpRoot:RsvpRoot?
    fileprivate var rsvpCreator:Card?
    fileprivate var rsvpThread:ChatThread?
    fileprivate var selectedCard:Card?
    
    //
    // MARK: Startup helper
    //
    
    class func showJoinThreadPopover(_ parent:UIViewController, rsvpPreview:RsvpPreviewResult) {
        let popover = JoinThreadViewController(nibName: "JoinThreadView", bundle: nil)
        popover.setup(rsvpPreview)
        showPopover(parent, popover:popover )
    }
    
    //
    // MARK: Init
    //
    
    func setup(_ preview:RsvpPreviewResult)
    {        
        //self.mycards = mycards
        rsvpRoot = preview.rsvp
        rsvpCreator = preview.card
        rsvpThread = preview.thread
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = String(format:"Accept invitation from %@".localized, rsvpCreator!.nickname! )
        let subject = rsvpThread!.subject!
        messageLabel.text = String(format:"Select the card you would like to represent you when chatting about '%@'".localized, subject )
        
        ImageHelper.round( cardImage )
        setMyCard( MyCardsModel.instance.cards.first! )
        
        let recognizer = UITapGestureRecognizer(target:self, action: #selector(changeCardAction) )
        cardRow.isUserInteractionEnabled = true
        cardRow.addGestureRecognizer(recognizer)
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackPopover( .joinChat, vc:self )
    }
    
    func setMyCard( _ card:Card ) {
        selectedCard = card
        cardNickname.text = card.nickname
        ImageHelper.fetchCardCoverImage(card.cid!, ofSize: UIConstants.CardCoverSize, forImageView: cardImage!)
    }
    
    func changeCardAction(_ sender: AnyObject) {
        MyCardChooserViewController.showCardChooser(self, cards: MyCardsModel.instance.cards ) {
            card in
            self.setMyCard(card)
        }
    }
    
    override func okButtonAction(_ sender: UIButton!) {
        let progress = ProgressIndicator(parent: view, message: "Accepting".localized )
        RsvpHelper.acceptRsvp(rsvpRoot!.secret!, mycid: selectedCard!.cid!) {
            success in
            
            DispatchQueue.main.async(execute: {
                progress.stop()
                if success {
                    self.dismiss(animated: true, completion: nil)
                    if let tid = self.rsvpThread?.tid {
                        NotificationHelper.signalShowChat( tid );
                    }
                    AnalyticsHelper.trackResult(.chatJoined)
                }
            })
        }
    }
}
