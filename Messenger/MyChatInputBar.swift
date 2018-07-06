//
//  MyChatInputBar.swift
//  Messenger
//
//  Created by Mike Prince on 2/15/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

protocol MyChatInputBarDelegate: class {
    func inputBarSendButtonPressed(_ message:String)
    func inputBarCameraButtonPressed()
}

class MyChatInputBar : UIView, UITextViewDelegate {
    
    static let DEBUG = false
    weak var delegate: MyChatInputBarDelegate?
    
    enum NotificationName: String {
        case HeightChange
        case BeginEditing
        case EndEditing
    }
    
    struct Constant {
        static let HEIGHT = CGFloat(44.0)
        static let MARGIN = CGFloat(6)
        static let BUTTON_SIZE = CGFloat(25)
    }
    
    let cameraButton = UIButton()
    let sendButton = UIButton()
    let textView = UITextView()
    let placeholder = UITextView()
    let roundedBackground = CALayer()
    
    class func create() -> MyChatInputBar {
        let width = UIScreen.main.bounds.width
        let view = MyChatInputBar(frame: CGRect(x: Constant.MARGIN,y: 0,width: width-Constant.MARGIN*2,height: Constant.HEIGHT))
        return view
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    fileprivate func commonInit() {
        roundedBackground.cornerRadius = 12.5
        roundedBackground.borderWidth = 0.5
        roundedBackground.borderColor = UIColor(white:0.7, alpha:1.0).cgColor
        roundedBackground.backgroundColor = UIColor.white.cgColor
        layer.addSublayer(roundedBackground)
        
        cameraButton.setImage(UIImage(named:"Camera"), for: UIControlState() )
        cameraButton.addTarget(self, action: #selector(cameraAction), for: .touchUpInside )
        addSubview(cameraButton)
        
        placeholder.font = UIFont.systemFont(ofSize: 16)
        placeholder.text = "Message Text (Placeholder)".localized
        placeholder.textContainerInset = UIEdgeInsets.zero
        placeholder.delegate = self
        addSubview(placeholder)
        
        textView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.textContainerInset = UIEdgeInsets.zero
        textView.isScrollEnabled = false
        textView.autocorrectionType = MyUserDefaults.instance.check(.DisableChatTextAutocorrection) ? .no : .yes
        textView.delegate = self
        insertSubview(textView, aboveSubview: placeholder)
        
        sendButton.setImage(UIImage(named:"Send Button"), for: UIControlState())
        sendButton.addTarget(self, action: #selector(sendAction), for: .touchUpInside )
        addSubview(sendButton)
        
        showPlaceholder()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let (screenWidth,textFrame) = calculateTextFrame()
        
        cameraButton.frame = CGRect(x: Constant.MARGIN * 2,y: textFrame.height - Constant.BUTTON_SIZE + 6, width: Constant.BUTTON_SIZE,height: Constant.BUTTON_SIZE)

        placeholder.frame = textFrame
        textView.frame = textFrame
        sendButton.frame = CGRect(x: textFrame.width + 3*Constant.MARGIN + Constant.BUTTON_SIZE,y: 0,width: Constant.BUTTON_SIZE,height: Constant.BUTTON_SIZE)
        
        let newHeight = textFrame.height + Constant.MARGIN
        self.frame = CGRect(x: 0,y: 0,width: screenWidth,height: newHeight + Constant.MARGIN)
        if MyChatInputBar.DEBUG { print( "chat input frame \(self.frame)" ) }
        roundedBackground.frame = CGRect(x: Constant.MARGIN,y: 0,width: screenWidth-Constant.MARGIN*2,height: newHeight)
        
        let notice = Notification(name:Notification.Name(rawValue: NotificationName.HeightChange.rawValue), object:newHeight )
        NotificationCenter.default.post(notice)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if StringHelper.clean( self.textView.text ) != nil {
            // there is some text in the message field
            hidePlaceholder()
            
            // should the text field height change?
            let (_,textFrame) = calculateTextFrame()
            if textFrame.height != textView.frame.height {
                self.setNeedsLayout()
            }
        } else {
            showPlaceholder()
        }
    }
    
    func textViewDidBeginEditing(_ textView:UITextView) {
        if textView == self.textView {
            let notice = Notification(name:Notification.Name(rawValue: NotificationName.BeginEditing.rawValue), object:nil )
            NotificationCenter.default.post(notice)
        }
    }
    
    func textViewDidEndEditing(_ textView:UITextView) {
        if textView == self.textView {
            let notice = Notification(name:Notification.Name(rawValue: NotificationName.EndEditing.rawValue), object:nil )
            NotificationCenter.default.post(notice)
        }
    }
    
    // layout is:
    // margin + camerabutton + margin + textinput + sendbutton + margin
    fileprivate func calculateTextFrame() -> (screenWidth:CGFloat,textFrame:CGRect) {
        let screenWidth = UIScreen.main.bounds.width
        let textWidth = screenWidth - 4 * Constant.MARGIN - 2 * Constant.BUTTON_SIZE
        let newTextSize = textView.sizeThatFits(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))
        let textFrame = CGRect(x: 2*Constant.MARGIN + Constant.BUTTON_SIZE,y: 4,width: textWidth,height: newTextSize.height)
        
        return (screenWidth,textFrame)
    }
    
    func cameraAction() {
        delegate?.inputBarCameraButtonPressed()
    }
    
    func sendAction() {
        if let text = StringHelper.clean( textView.text ) {
            delegate?.inputBarSendButtonPressed(text)
        }
        
        textView.text = nil
        setNeedsLayout()
        showPlaceholder()
    }
    
    fileprivate func showPlaceholder() {
        placeholder.textColor = UIColor(white:0.7, alpha:1.0)
    }
    
    fileprivate func hidePlaceholder() {
        placeholder.textColor = UIColor.clear
    }
}
