import Foundation

extension String {
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }
    
    func truncate(length: Int, trailing: String = "…") -> String {
        if self.characters.count > length {
            return String(self.characters.prefix(length)) + trailing
        } else {
            return self
        }
    }
}

class StringHelper {
    
    struct Const {
        static let ALLOWED = CharacterSet(charactersIn:"=\"#%/<>?@\\^`{|}").inverted
    }
    
    class func urlEncode(_ s:String) -> String {
        let escaped = s.addingPercentEncoding(withAllowedCharacters: Const.ALLOWED)
        return escaped!
    }
    
    class func countWords(_ s:String?) -> Int {
        if let s = s {
            let words = s.components(separatedBy: " ")
            return words.count
        } else {
            return 0
        }
    }
    
    class func clean(_ s:String?) -> String? {
        if s == nil {
            return nil
        }
        
        //let result = s!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        //if result.isEmpty {
        //    return nil
        //}
        
        let components = s!.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        let result = components.filter { !$0.isEmpty }.joined(separator: " ")
        
        return result.isEmpty ? nil : result
        
        // Swift3:
        //let components = s!.components(separatedBy: NSCharacterSet.whitespacesAndNewlines)
        //return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
    
    class func ensure(_ s:String?) -> String {
        return s == nil ? "" : s!
    }
    
    class func isEqual( _ s1:String?, s2:String? ) -> Bool {
        if s1 == nil && s2 == nil {
            return true
        } else if s1 == nil || s2 == nil {
            return false
        } else {
            return s1 == s2
        }
    }
    
    // convert comma separated values into array
    class func asArray(_ csv:String?) -> [String]? {
        if csv == nil {
            return nil
        } else if csv!.isEmpty {
            return [String]()
        } else {
            return csv!.characters.split{$0 == ","}.map(String.init)
        }
    }
    
    class func toCsv(_ array:[String]?) -> String? {
        if array == nil {
            return nil
        } else {
            return array?.joined(separator: ",")
        }
    }
    
    class func toString( _ dict:[AnyHashable: Any] ) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted )
            let s = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue )!
            return s as String
        } catch {
            print(error)
            return "Failed to convert dictionary to JSON"
        }
    }
    
    class func isValidEmail(_ email:String?) -> Bool {
        if let email = email {
            let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        
            let predicate = NSPredicate(format:"SELF MATCHES %@", regex)
            return predicate.evaluate(with: email)
        } else {
            return false
        }
    }
}
