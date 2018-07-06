import UIKit

class RecentChatCardTableViewCell: UITableViewCell {
    
    static let TABLE_CELL_IDENTIFIER = "RecentChatCardTableViewCell"
    struct Constants {
        static let Height:CGFloat = 50
    }
    
    @IBOutlet weak var cardImage: ReusableImageView!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var taglineLabel: UILabel!
    
    fileprivate var cid:String?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String!) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    func refresh( _ contact: ChatContact ) {
        nicknameLabel.text = nil
        taglineLabel.text = nil
        cid = contact.cid
        ImageHelper.round( cardImage )
        
        // show image of last message poster
        cardImage.image = nil     // clear until new one loads
        ImageHelper.fetchThreadCardCoverImage(contact.tids![0], cid:contact.cid!, ofSize:UIConstants.CardCoverSize, forImageView:cardImage)
        
        // fetch nickname and tagline
        CardHelper.fetchThreadCard(contact.tids![0], cid:contact.cid! ) {
            card in
            
            // make sure cell is still showing the card we fetched for
            if self.cid == card.cid {
                UIHelper.onMainThread {
                    if self.cid == card.cid {   // double check, in case of race
                        self.nicknameLabel.text = card.nickname
                        self.taglineLabel.text = card.tagline
                    }
                }
            }
        }
    }
}
