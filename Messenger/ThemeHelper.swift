//
//  ThemeHelper.swift
//  Messenger
//
//  Created by Mike Prince on 2/13/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class ThemeHelper {
    
    enum ThemeType: String {
        case SIMPLE
        case PRO
    }
    
    static let THEME_LIST:[KeyedLabel] = [KeyedLabel(key:ThemeType.SIMPLE.rawValue,label:"Simple (Theme)".localized),
                             KeyedLabel(key:ThemeType.PRO.rawValue,label:"Pro (Theme)".localized)]
    
    class func asThemeLabel(_ key:String?) -> String {
        for t in THEME_LIST {
            if t.key == key {
                return t.label
            }
        }
        
        return "?"
    }
    
    class func isSimpleTheme() -> Bool {
        return MyUserDefaults.instance.getTheme() == ThemeType.SIMPLE.rawValue
    }
    
    static let DefaultButtonColor = UIButton(type: UIButtonType.system).titleColor(for: UIControlState())!
    
    class func themeColor() -> UIColor {
        return DefaultButtonColor
    }
}
