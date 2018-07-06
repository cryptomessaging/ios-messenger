import Foundation

protocol BotScriptDelegate: class {
    func doBotWidgetHeightChange(_ height:CGFloat)
    
    func fetchThreadCards() -> [Card]?
    func fetchUserCard() -> Card?
    func doSelectUserCard( options:SelectUserCardOptions?, completion:@escaping( _ failure:Failure?, _ card:Card?) -> Void ) -> Void  // request user to pick one of their cards, or create a new one
    func fetchBotCard() -> Card?
    
    func fetchThreadList( _ tids:[String] ) -> ThreadListResult
    func fetchThread() -> ChatThread?
    func fetchMessageHistory() -> [ChatMessage]?

    func doSetOptionButtonItems( _ items:[OptionItem] )
    func doEnvironmentFixup( _ env:inout WidgetEnvironment )
    func doSetupScreen( _ options:ScreenOptions )
    func doSetBackButton( _ options:BackButtonOptions? )
    
    func doCloseBotWidget()
    
    func doEnsureExclusiveChat( subject:String?, updateRestClient:Bool, _ completion:@escaping( _ failure:Failure?, _ thread:ChatThread?) -> Void ) -> Void
    func doShowChat( _ options:ShowChatOptions )
}
