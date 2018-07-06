import Foundation

struct UIConstants {
    static let RowHeight:CGFloat = 44
    static let CardCoverSize = "c100"       // for fetches from server
    
    static let DefaultBotWidgetHeight:CGFloat = 44
    
    // be consistent with cover images
    // also used for chat heads
    static let CardCoverDiameter:CGFloat = 40   // assuming its always round, so both width and height
    
    static let RegularFontSize:CGFloat = 20.0
    static let SmallFontSize:CGFloat = 10.0
    
    static let InternalMargin:CGFloat = 8
    
    // be consistent with corners
    static let CornerRadius:CGFloat = 10
    
    // full screen background, for behind full view card, group chat, etc.
    static let LightGrayBackground = UIColor(white: 240/255.0, alpha: 1)
    
    // bot toolbar
    static let LightBlueBackground = UIColor(red: 215/255.0, green: 236/255.0, blue: 1, alpha: 1)
    static let LeftBorderWidth:CGFloat = 3
    
    // tool tips
    static let ToolTipBackground = UIColor(red: 0.07, green:0.6, blue:0.835, alpha:1 )
    static let TipDelay = 1.0
    //static let showTips = false
    
    static let requireNewUserCard = false
    static let offerQuickstart = false
    static let automaticAnonymousAccount = true
}
