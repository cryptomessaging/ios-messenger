import Foundation
import UIKit

class GearOverlayView: UIView {
    var enabled = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect ) {
        super.init(frame: frame )
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init( coder: aDecoder )
        commonInit()
    }
    
    func commonInit() {
        self.isOpaque = false
    }
    
    override func draw( _ rect: CGRect ) {
        if !enabled {
            return
        }
        
        UIColor(white: 210/255.0, alpha: 1).setStroke()
        
        let imageSize = UIConstants.CardCoverDiameter
        let margin = UIConstants.InternalMargin
        let radius = imageSize / 2
        let center = CGPoint( x: radius + margin, y: radius + margin )
        
        // solid circle/ring
        let ringThickness:CGFloat = 3
        let path = UIBezierPath(arcCenter: center,
                                radius: radius - ringThickness / 2,
                                startAngle: 0,
                                endAngle: 2.0 * CGFloat(M_PI),
                                clockwise: true)
        
        path.lineWidth = ringThickness
        path.stroke()
        
        // teeth
        let toothThickness:CGFloat = 3
        let teeth = 10;
        let toothWidth = CGFloat( 2.0 * M_PI / Double(teeth) )
        
        for i in 1...teeth {
            let startAngle = CGFloat(i) * toothWidth
            let endAngle = startAngle + toothWidth / 2
            let path = UIBezierPath(arcCenter: center,
                                    radius: radius + toothThickness / 2,
                                    startAngle: startAngle,
                                    endAngle: endAngle,
                                    clockwise: true)
            
            path.lineWidth = toothThickness
            path.stroke()
        }
    }
}

class SmallCardView: UIView, CardPresenter {
    
    struct Constants {
        static let NicknameFontSize:CGFloat = 13.0
        static let Width:CGFloat = 120
        static let Height:CGFloat = UIConstants.InternalMargin * 2 + UIConstants.CardCoverDiameter
    }
    
    fileprivate var card:Card?
    fileprivate let isSimpleTheme = ThemeHelper.isSimpleTheme()
    fileprivate let coverImage = ReusableImageView()
    fileprivate let nicknameLabel = UILabel()
    fileprivate var taglineLabelFrameBounds:CGRect!
    fileprivate let taglineLabel = UILabel()
    fileprivate let bottomBorder = CALayer()    // bot colored underline
    fileprivate var gearOverlay = GearOverlayView( frame: CGRect(x: 0, y: 0, width: Constants.Width, height: Constants.Height ) )
    fileprivate var pillOverlay = CALayer()     // optional pill background
    
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
        layer.addSublayer( bottomBorder )
        layer.addSublayer( pillOverlay )
        
        let imageSize = UIConstants.CardCoverDiameter
        coverImage.frame = CGRect(x:UIConstants.InternalMargin, y:UIConstants.InternalMargin, width:imageSize, height:imageSize)  // always top left
        ImageHelper.round(coverImage)
        addSubview(coverImage)
        
        let x = UIConstants.InternalMargin + imageSize + UIConstants.InternalMargin
        let width = Constants.Width - x
        let nicknameHeight:CGFloat = 14.0
        nicknameLabel.frame = CGRect(x:x, y:UIConstants.InternalMargin + 2, width:width, height:nicknameHeight )
        nicknameLabel.font = UIFont.boldSystemFont(ofSize: Constants.NicknameFontSize)
        nicknameLabel.baselineAdjustment = .alignCenters
        nicknameLabel.textColor = UIColor.darkText
        nicknameLabel.adjustsFontSizeToFitWidth = true
        nicknameLabel.minimumScaleFactor = 0.3
        nicknameLabel.backgroundColor = UIColor.clear
        addSubview(nicknameLabel)
        
        let y = UIConstants.InternalMargin + nicknameHeight
        taglineLabelFrameBounds = CGRect(x:x, y:y, width:width, height:Constants.Height - y - 6)
        taglineLabel.font = taglineLabel.font.withSize(UIConstants.SmallFontSize)
        taglineLabel.textColor = UIColor.darkText
        taglineLabel.numberOfLines = 2
        taglineLabel.backgroundColor = UIColor.clear
        addSubview(taglineLabel)
        
        addSubview( gearOverlay )
        bringSubview(toFront: gearOverlay)    // make sure its on top
    }
    
    func setCard( _ card:Card, tid:String?, color:CGColor ) {
        self.card = card
        
        gearOverlay.enabled = card.isBot()
        bottomBorder.backgroundColor = color
        nicknameLabel.text = card.nickname
        taglineLabel.text = card.tagline
        resizeTagline()

        if let tid = tid {
            ImageHelper.fetchThreadCardCoverImage(tid, cid: card.cid!, ofSize: UIConstants.CardCoverSize, forImageView: coverImage )
        } else {
            ImageHelper.fetchCardCoverImage( card.cid!, ofSize: UIConstants.CardCoverSize, forImageView: coverImage )  
        }
    }
    
    // when tagline is just one line, vertical align to top
    func resizeTagline() {
        if let text = taglineLabel.text {
            let size = (text as NSString).size( attributes:[NSFontAttributeName: taglineLabel.font])
            if size.width < taglineLabelFrameBounds.width {
                // more than one line
                let orig = taglineLabelFrameBounds!
                taglineLabel.frame = CGRect(origin:orig.origin, size:CGSize(width:orig.width, height:size.height))
                return
            }
        }
        
        // falling through, means two+ lines and use maximal frame bounds
        taglineLabel.frame = taglineLabelFrameBounds
    }
    
    func cellSize() -> CGSize {
        return CGSize( width: Constants.Width, height: Constants.Height )
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let borderHeight = CGFloat(3)
        if isSimpleTheme {
            bottomBorder.frame = CGRect(x: 10, y: Constants.Height - borderHeight, width: Constants.Width - 6, height: borderHeight )
        } else {
            bottomBorder.frame = CGRect(x: 0, y: Constants.Height - borderHeight, width: Constants.Width, height: borderHeight )
        }
        
        pillOverlay.backgroundColor = UIConstants.LightGrayBackground.cgColor
        pillOverlay.frame = CGRect(x: 10, y: 8, width: Constants.Width, height: Constants.Height - 16)
        pillOverlay.cornerRadius = 20.0
    }
}
