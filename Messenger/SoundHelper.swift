import Foundation

class SoundHelper {
    
    enum Setting: String {
        case ALWAYS_ON
        case MUTABLE
    }
    
    static let SETTING_LIST:[KeyedLabel] = [KeyedLabel(key:Setting.ALWAYS_ON.rawValue,label:"Alerts Always On (Theme)".localized),
                                          KeyedLabel(key:Setting.MUTABLE.rawValue,label:"Alerts Mutable (Theme)".localized)]
    
    class func asLabel(_ key:String?) -> String {
        for t in SETTING_LIST {
            if t.key == key {
                return t.label
            }
        }
        
        return "?"
    }
    
    class func isAlwaysOn() -> Bool {
        return MyUserDefaults.instance.getSoundSetting() == Setting.ALWAYS_ON.rawValue
    }
    
    /*
    static let DefaultButtonColor = UIButton(type: UIButtonType.system).titleColor(for: UIControlState())!
    
    class func themeColor() -> UIColor {
        return DefaultButtonColor
    }*/
}
