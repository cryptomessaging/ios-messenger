import Foundation

class DiffieHellman {
    
    fileprivate static let DEBUG = false
    fileprivate let now = TimeHelper.as8601(Date())
    
    fileprivate var digest:HMACDigest?
    fileprivate var ckid:String!     // my card key id
    fileprivate var bkid:String!     // bot key id
    
    fileprivate let preamble:String
    fileprivate let mycid:String!
    fileprivate let tid:String?
    fileprivate let myPrivateKey:Crypto!
    fileprivate let botPublicKeys:[String:Crypto]!
    
    init(method:String, path:String, host:String, mycid:String?, myPrivateKey:Crypto?, tid:String?, botPublicKeys:[String:Crypto]?) {
        self.preamble = "\(method) \(path)\n\(host)\n\(now)\n"
        self.mycid = mycid
        self.tid = tid
        self.myPrivateKey = myPrivateKey
        self.botPublicKeys = botPublicKeys
    }
    
    func start() -> Failure? {
        // sanity
        if mycid == nil {
            return Failure( message:"DiffieHellman requires mycid".localized )
        }
        
        if myPrivateKey == nil {
            return Failure( message:"DiffieHellman requires myPrivateKey".localized )
        }
        
        if myPrivateKey.id == nil {
            return Failure( message:"DiffieHellman requires myPrivateKey.id".localized )
        }
        ckid = myPrivateKey.id
        let privateKey = myPrivateKey.values![1]
        let type = myPrivateKey.type!
        
        // select bot key
        guard let botPublicKey = DiffieHellman.selectPublicKey( myPrivateKey.type, botPublicKeys: botPublicKeys ) else {
            let type = myPrivateKey.type == nil ? "nil" : myPrivateKey.type!
            let msg = String(format:"DiffieHellman failed to find bot key of type %@".localized, type )
            return Failure( message: msg )
        }
        bkid = botPublicKey.id!
        let publicKey = botPublicKey.values![0]
        
        // craft the shared secret
        let secret = createSharedSecret(type, base64privateKey: privateKey, base64publicKey: publicKey )
    
        digest = HMACDigest(algorithm: CryptoAlgorithm.sha256, key:secret)
        digest?.updateWithString(preamble);
        if DiffieHellman.DEBUG { print( "start() digest with preamble \(preamble)") }
        
        return nil
    }
    
    class func selectPublicKey(_ type:String?, botPublicKeys:[String:Crypto]? ) -> Crypto? {
        if let type = type, let botKeys = botPublicKeys {
            for(id,crypto) in botKeys {
                if crypto.type == type {
                    crypto.id = id
                    return crypto
                }
            }
        }
        
        return nil
    }
    
    func update( _ data: Data ) {
        digest?.updateWithData(data)
    }
    
    func getDate() -> String {
        return now
    }
    
    func getAuthorization() -> String {
        let sig = digest?.digest()
        var auth:String
        if let tid = self.tid {
            auth = "CB-HMAC algo=sha256,cid=\(mycid!),tid=\(tid),ckid=\(ckid!),bkid=\(bkid!),headers=Host;X-Mobido-Date,sig=\(sig!)"
        } else {
            auth = "CB-HMAC algo=sha256,cid=\(mycid!),ckid=\(ckid!),bkid=\(bkid!),headers=Host;X-Mobido-Date,sig=\(sig!)"
        }

        if DiffieHellman.DEBUG { print( "Auth is \(auth)") }
        return auth;
    }
    
    func createSharedSecret(_ type:String, base64privateKey:String, base64publicKey:String) -> String {
        
        // create DiffieHellman with modp prime and generator
        let dh = DH_new()
        if !diffie_init(dh, type ) {
            DH_free(dh)
            print( "Failed to init() DH" );
            return "Error: Failed to init() DH"
        }
        
        // set the private key
        let privateKey = Data(base64Encoded: base64privateKey, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters)!
        diffie_set_private_key(dh, (privateKey as NSData).bytes.bindMemory(to: UInt8.self, capacity: privateKey.count), Int32(privateKey.count) );
        
        // convert public key to raw bytes
        let publicKey = Data(base64Encoded: base64publicKey, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters)!
        
        // compute the secret key
        var secretLength:Int32 = 0
        let secretBuffer = diffie_compute_secret(dh, (publicKey as NSData).bytes.bindMemory(to: UInt8.self, capacity: publicKey.count), Int32(publicKey.count), &secretLength )
        if secretLength == -1 {
            // An error!  Reason is in the secretBuffer, and no need to release it
            let reason = String(cString: UnsafePointer(secretBuffer!))
            DH_free(dh)
            let msg = "Error: \(reason)"
            DebugLogger.instance.append( function:"createSharedSecret()", message:"Error computing secret \(reason)")
            return msg
        } else {
            // convert secret bytes back to base64
            let data = Data( bytes: UnsafePointer<UInt8>(secretBuffer!), count:Int(secretLength) )
            let base64 = data.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
            free( secretBuffer )
            DH_free(dh)
            
            if DiffieHellman.DEBUG { print( "Shared secret is \(base64)") }
            return base64;
        }
    }
}
