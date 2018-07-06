import Foundation

// Make sure you add #import <CommonCrypto/CommonCrypto.h> to the Xcode bridging header!

enum CryptoAlgorithm {
    case md5, sha1, sha224, sha256, sha384, sha512
    
    var HMACAlgorithm: CCHmacAlgorithm {
        var result: Int = 0
        switch self {
        case .md5:      result = kCCHmacAlgMD5
        case .sha1:     result = kCCHmacAlgSHA1
        case .sha224:   result = kCCHmacAlgSHA224
        case .sha256:   result = kCCHmacAlgSHA256
        case .sha384:   result = kCCHmacAlgSHA384
        case .sha512:   result = kCCHmacAlgSHA512
        }
        return CCHmacAlgorithm(result)
    }
    
    var digestLength: Int {
        var result: Int32 = 0
        switch self {
        case .md5:      result = CC_MD5_DIGEST_LENGTH
        case .sha1:     result = CC_SHA1_DIGEST_LENGTH
        case .sha224:   result = CC_SHA224_DIGEST_LENGTH
        case .sha256:   result = CC_SHA256_DIGEST_LENGTH
        case .sha384:   result = CC_SHA384_DIGEST_LENGTH
        case .sha512:   result = CC_SHA512_DIGEST_LENGTH
        }
        return Int(result)
    }
}

/*
extension String {
    
    func hmac(algorithm: CryptoAlgorithm, key: String) -> String {
        let str = self.cStringUsingEncoding(NSUTF8StringEncoding)
        let strLen = Int(self.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        let digestLen = algorithm.digestLength
        let result = UnsafeMutablePointer<CUnsignedChar>.alloc(digestLen)
        let keyStr = key.cStringUsingEncoding(NSUTF8StringEncoding)
        let keyLen = Int(key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        
        CCHmac(algorithm.HMACAlgorithm, keyStr!, keyLen, str!, strLen, result)
        
        let digest = stringFromResult(result, length: digestLen)
        
        result.dealloc(digestLen)
        
        return digest
    }
    
    private func stringFromResult(result: UnsafeMutablePointer<CUnsignedChar>, length: Int) -> String {
        let hash = NSMutableString()
        for i in 0..<length {
            hash.appendFormat("%02x", result[i])
        }
        return String(hash)
    }
    
}
*/


/*!
@function   CCHmacInit
@abstract   Initialize an CCHmacContext with provided raw key bytes.

@param      ctx         An HMAC context.
@param      algorithm   HMAC algorithm to perform.
@param      key         Raw key bytes.
@param      keyLength   Length of raw key bytes; can be any
length including zero.

void CCHmacInit(
CCHmacContext *ctx,
CCHmacAlgorithm algorithm,
const void *key,
size_t keyLength)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0);


/*!
@function   CCHmacUpdate
@abstract   Process some data.

@param      ctx         An HMAC context.
@param      data        Data to process.
@param      dataLength  Length of data to process, in bytes.

@discussion This can be called multiple times.
*/
void CCHmacUpdate(
CCHmacContext *ctx,
const void *data,
size_t dataLength)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0);


/*!
@function   CCHmacFinal
@abstract   Obtain the final Message Authentication Code.

@param      ctx         An HMAC context.
@param      macOut      Destination of MAC; allocated by caller.

@discussion The length of the MAC written to *macOut is the same as
the digest length associated with the HMAC algorithm:

kCCHmacSHA1 : CC_SHA1_DIGEST_LENGTH

kCCHmacMD5  : CC_MD5_DIGEST_LENGTH
*/
void CCHmacFinal(
CCHmacContext *ctx,
void *macOut)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0);

*/

class HMACDigest {
    
    fileprivate var hmacContext:CCHmacContext
    fileprivate var digestLength:Int
    
    init(algorithm:CryptoAlgorithm, key:String) {
        hmacContext = CCHmacContext()
        digestLength = algorithm.digestLength
        
        let keyStr = key.cString(using: String.Encoding.utf8)
        let keyLen = Int(key.lengthOfBytes(using: String.Encoding.utf8))
        //printBytes( "secret", result: keyStr!, length: keyLen )
        
        CCHmacInit( &hmacContext,algorithm.HMACAlgorithm, keyStr!, keyLen )
    }
    
    func updateWithString(_ string:String) {
        let data = string.cString(using: String.Encoding.utf8)
        let length = Int(string.lengthOfBytes(using: String.Encoding.utf8))
        
        //printBytes( "update", result: data!, length: length )
        CCHmacUpdate( &hmacContext, data!,length)
    }
    
    func updateWithData(_ data:Data) {
        CCHmacUpdate( &hmacContext, (data as NSData).bytes, data.count)
    }
    
    func digest() -> String {
        // calculate digest and wrap in NSData
        var digestBuffer = Array<UInt8>(repeating: 0, count: digestLength)
        CCHmacFinal(&hmacContext,&digestBuffer)
        //let data = Data( bytes: UnsafePointer<UInt8>(&digestBuffer), length:digestLength )
        let data = Data( buffer: UnsafeBufferPointer(start:&digestBuffer, count:digestLength) )
        
        //printBytes( "digest", from: digestBuffer, length: digestLength )
        
        // convert buffer to base64
        let base64 = data.base64EncodedString(options: Data.Base64EncodingOptions.lineLength76Characters)
        
        return base64
    }
}

