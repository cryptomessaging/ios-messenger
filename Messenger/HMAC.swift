import Foundation

class HMAC {
    
    static let DEBUG = false
    fileprivate let now = TimeHelper.as8601(Date())
    fileprivate var accesskey:AccessKey
    fileprivate var digest:HMACDigest
    
    init(method:String, fullpath:String, host:String, accesskey:AccessKey) {
        self.accesskey = accesskey
        
        digest = HMACDigest(algorithm: CryptoAlgorithm.sha256, key:accesskey.secret!)

        let preamble = "\(method) \(fullpath)\n\(host)\n\(now)\n"
        if HMAC.DEBUG {
            let message = "Preamble \(preamble) size:\(preamble.characters.count) secret:\(String(describing: accesskey.secret))"
            DebugLogger.instance.append( function:"HMAC.init()", message:message )
        }
        digest.updateWithString(preamble);
    }
    
    func update( _ data: Data ) {
        digest.updateWithData(data)
    }
    
    func getDate() -> String {
        return now
    }
    
    func getAuthorization() -> String {
        let sig = digest.digest()
        let auth = "HMAC-SHA256 id=\(accesskey.id!),headers=Host;X-Mobido-Date,sig=\(sig)"
        if HMAC.DEBUG {
            DebugLogger.instance.append( function:"getAuthorization()", message:auth )
        }
        return auth;
    }
}
