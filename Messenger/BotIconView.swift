import Foundation
import UIKit

// cards as icons for bots
/* each image has a colored border
class BotIconView: UIView, CardPresenter {
    
    struct Constants {
        static let iconDiameter:CGFloat = 25
        static let iconSideMargin:CGFloat = 16
        static let iconTopMargin:CGFloat = 8
        static let iconBottomMargin:CGFloat = UIConstants.InternalMargin
        static let labelHeight:CGFloat = 13.0
        
        static let IconBorderWidth:CGFloat = 2
        
        static let Width = iconSideMargin * 2 + iconDiameter
        static let Height = iconTopMargin + iconDiameter + iconBottomMargin + labelHeight + UIConstants.InternalMargin
    }
    
    fileprivate var card:Card?
    fileprivate var iconBorder = CALayer()
    
    fileprivate let iconImage = ReusableImageView()
    fileprivate let botnameLabel = UILabel()
    
    override init(frame: CGRect ) {
        super.init(frame: frame )
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init( coder: aDecoder )
        commonInit()
    }
    
    fileprivate func commonInit() {
        autoresizingMask = UIViewAutoresizing()
        translatesAutoresizingMaskIntoConstraints = false
        
        iconImage.frame = CGRect(x: Constants.iconSideMargin,y: Constants.iconTopMargin,width: Constants.iconDiameter,height: Constants.iconDiameter)
        ImageHelper.round(iconImage)
        addSubview( iconImage )

        let y = Constants.iconTopMargin + Constants.iconDiameter + Constants.iconBottomMargin
        botnameLabel.frame = CGRect(x: 0,y: y,width: Constants.Width,height: Constants.labelHeight)
        botnameLabel.adjustsFontSizeToFitWidth = false
        botnameLabel.font = botnameLabel.font.withSize(UIConstants.SmallFontSize)
        botnameLabel.textAlignment = .center
        addSubview( botnameLabel )
        
        iconBorder.frame = UIHelper.grow( iconImage.frame, border: Constants.IconBorderWidth )
        iconBorder.cornerRadius = iconBorder.frame.size.width / 2
        //iconBorder.borderColor = UIColor.orangeColor().CGColor
        iconBorder.borderWidth = Constants.IconBorderWidth
        layer.addSublayer( iconBorder )
    }
    
    func setCard( _ card:Card, tid:String, color:CGColor ) {
        self.card = card
        
        botnameLabel.text = card.nickname
        iconBorder.borderColor = color
        
        if let bot = card as? LocalBotCard {
            iconImage.image = bot.icon
        } else {
            ImageHelper.fetchThreadCardCoverImage(tid, cid: card.cid!, ofSize: UIConstants.CardCoverSize, forImageView: iconImage )
        }
    }
    
    func cellSize() -> CGSize {
        return CGSize( width: Constants.Width, height: Constants.Height )
    }
}
 */
