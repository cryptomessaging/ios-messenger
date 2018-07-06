//
//  BotOptionButton.swift
//  Messenger
//
//  Created by Mike Prince on 4/12/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class BotOptionButton : UIImageView {
    
    static let HAMBURGER_SIZE = CGFloat(40.0)
    let circleLayer = CAShapeLayer()
    var items:[OptionItem]?
    
    // for handling option button taps
    fileprivate weak var botScriptBridge:BotScriptBridge?
    fileprivate weak var delegate:BotScriptDelegate?
    weak var vc:UIViewController?
    fileprivate weak var parentView:UIView?
    fileprivate var yoffset:CGFloat = 0
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame )
        commonInit()
    }
    
    init() {
        super.init( frame: CGRect.zero )
        commonInit()
    }
    
    // action: #selector(onOptionsTapped))
    func commonInit() {
        
        self.image = UIImage(named: "Hamburger")
        self.contentMode = .center
        
        // add circle background
        circleLayer.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: BotOptionButton.HAMBURGER_SIZE, height: BotOptionButton.HAMBURGER_SIZE) ).cgPath
        circleLayer.isOpaque = true
        circleLayer.opacity = 0.5
        circleLayer.fillColor = ThemeHelper.themeColor().cgColor
        self.layer.addSublayer( circleLayer )

        // wire up tap handler
        self.isUserInteractionEnabled = true
        let singleTap = UITapGestureRecognizer( target:self, action:#selector(onOptionButtonTapped) )
        singleTap.numberOfTapsRequired = 1
        self.addGestureRecognizer(singleTap)
    }
    
    func setup( parentView:UIView, bridge:BotScriptBridge, delegate:BotScriptDelegate, yoffset:CGFloat = 0 ) {
        self.parentView = parentView
        self.botScriptBridge = bridge
        self.delegate = delegate
        self.yoffset = yoffset
    }
    
    // when user taps on bot widget option button
    func onOptionButtonTapped(_ sender:UITapGestureRecognizer) {
        
        guard let vc = vc else {
            DebugLogger.instance.append( "ERROR: BotOptionButton.setup() not called" )
            return
        }
        
        guard let bridge = self.botScriptBridge, let botCard = bridge.botCard else {
            DebugLogger.instance.append( "onOptionButtonTapped() before bot finished setting up" )
            return
        }

        let nav = vc.navigationController!
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        if let items = self.items {
            for i in items {
                let aboutAction = UIAlertAction(title: i.label, style: .default, handler: {
                    action in
                    
                    if let url = i.url {
                        FullBotViewController.showBotView( nav, url:url, title:i.label!, bridge:bridge, delegate:self.delegate! )
                    } else if let id = i.id {
                        self.botScriptBridge?.onOptionItemSelected(id)
                    }
                })
                alert.addAction( aboutAction )
            }
        }
        
        let aboutAction = UIAlertAction(title: "About bot".localized, style: .default, handler: {
            action in
            FullCard2ViewController.showFullCardView( nav, card:botCard, tid:bridge.tid, mycid:bridge.mycid )
        })
        alert.addAction( aboutAction )
        
        UIHelper.ipadFixup( alert, sender:sender, inView:parentView! )
        vc.present(alert, animated: true, completion: nil)
        AnalyticsHelper.trackPopover( .widgetOptions, vc:alert )
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        let xoffset = UIScreen.main.bounds.width - BotOptionButton.HAMBURGER_SIZE - 5
        frame = CGRect( x:xoffset, y:yoffset + 5, width:BotOptionButton.HAMBURGER_SIZE, height:BotOptionButton.HAMBURGER_SIZE );
    }
}
