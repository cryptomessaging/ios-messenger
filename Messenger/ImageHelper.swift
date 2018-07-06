import UIKit

class ImageHelper {
    
    static let DEBUG = false
    static let ZERO_LENGTH_BASE64 = "="
    
    static let anonymousCardCover = UIImage(named:"cover image placeholder")!
    static let fetchingMediaIcon = UIImage(named:"Fetching Media" )!
    static let unknownMediaIcon = UIImage(named:"Unknown Media" )!
    
    class func toDataUri( _ base64:String ) -> String {
        return "data:image/jpeg;base64,\(base64)"
    }
    
    class func round(_ image:UIImageView) {
        let size = image.frame.size
        image.layer.cornerRadius = size.width / 2
        image.clipsToBounds = true
    }
    
    class func round(_ image:UIImageView, radius:CGFloat) {
        image.layer.cornerRadius = radius
        image.clipsToBounds = true
    }
    
    class func fetchChatImage( msg:ChatMessage, index:Int, ofSize:String, forImageView imageView:UIImageView) {
        if ImageHelper.DEBUG { print("Fetch thread message media for \(msg) [\(index)] size \(ofSize)") }
        
        let owner = NSObject()
        if let imageView = imageView as? ReusableImageView {
            imageView.owner = owner
        }
        
        LruCache.instance.fetchChatImage(msg, index:index, size:ofSize, imageView: imageView, onSuccess: { image in
            if verifyImageView( imageView, isOwnedBy:owner ) {
                imageView.image = image
                imageView.contentMode = .scaleToFill
            }
            
        }) {error in
            // failed to get cover from cache, so go across network
            if ImageHelper.DEBUG { print("Fetching thread image from server for \(msg)[\(index)] of size \(ofSize) because \(error)") }
            MobidoRestClient.instance.fetchChatMedia(msg.tid!, cid:msg.from!, created:msg.created!, index:index, size:ofSize) { failure,data,response in
                
                // has the imageview been reused, and we can discard this result?
                if verifyImageView( imageView, isOwnedBy:owner ) != true {
                    return
                }
                
                if let fail = failure {
                    if fail.statusCode == 204 {
                        // use the image placeholder, TODO error placeholder
                        let empty = unknownMediaIcon
                        UIHelper.onMainThread {
                            imageView.image = empty
                            imageView.contentMode = .center
                        }
                        LruCache.instance.saveChatImage(msg, index:index, size:ofSize, image:empty )
                    } else {
                        imageView.image = fetchingMediaIcon
                        imageView.contentMode = .center
                        DebugLogger.instance.append( function: "handleFetch()", message:"Failed to get image from server \(fail.message)" )
                    }
                } else {
                    let image = UIImage( data: data! )
                    UIHelper.onMainThread {
                        imageView.image = image
                        imageView.contentMode = .scaleToFill
                    }
                    LruCache.instance.saveChatImage(msg, index:index, size:ofSize, image:image! )
                }
            }
        }
    }
    
    class func verifyImageView( _ imageView:UIImageView, isOwnedBy:NSObject) -> Bool {
        if let imageView = imageView as? ReusableImageView {
            return imageView.owner == isOwnedBy
        } else {
            return true
        }
    }
    
    class func fetchThreadCardCoverImage(_ tid:String, cid:String, ofSize:String, forImageView imageView:UIImageView) {
        if ImageHelper.DEBUG { print("Fetch thread \(tid) image of card \(cid) size \(ofSize)") }
        
        let owner = NSObject()
        if let imageView = imageView as? ReusableImageView {
            imageView.owner = owner
        }
        
        imageView.image = anonymousCardCover
        LruCache.instance.fetchCardCoverImage(cid, size:ofSize, imageView: imageView, onSuccess: { image in
            if verifyImageView( imageView, isOwnedBy:owner ) {
                imageView.image = image
            }
            
        }) {error in
            // failed to get cover from cache, so go across network
            if ImageHelper.DEBUG { print("Fetching thread image from server \(cid) of size \(ofSize) because \(String(describing: error))") }
            MobidoRestClient.instance.fetchThreadCardCover(tid, cid:cid, size:ofSize ) { failure,data,response in
                
                // Is the image still mine, or has it been reused?
                if verifyImageView( imageView, isOwnedBy:owner ) {
                    handleFetch( cid, ofSize:ofSize, forImageView:imageView, failure:failure, data:data, response:response )
                }
            }
        }
    }
    
    // a public card, or one of mine
    class func fetchCardCoverImage(_ cid:String, ofSize:String, forImageView imageView:UIImageView) {
        let owner = NSObject()
        if let imageView = imageView as? ReusableImageView {
            imageView.owner = owner
        }
        
        imageView.image = anonymousCardCover
        LruCache.instance.fetchCardCoverImage(cid, size:ofSize, imageView:imageView, onSuccess: { image in
            if verifyImageView( imageView, isOwnedBy:owner ) {
                imageView.image = image
            }
        }) { error in
            // failed to get cover from cache, so go across network
            if ImageHelper.DEBUG { print("Fetching image from server") }
            MobidoRestClient.instance.fetchCardCover(cid, size:ofSize ) { failure,data,response in
                
                // Is the image still mine, or has it been reused?
                if verifyImageView( imageView, isOwnedBy:owner ) {
                    handleFetch( cid, ofSize:ofSize, forImageView:imageView, failure:failure, data:data, response:response )
                }
            }
        }
    }
    
    class func handleFetch(_ cid:String, ofSize:String, forImageView:UIImageView, failure:Failure?, data:Data?, response:URLResponse? ) {
        if let fail = failure {
            if fail.statusCode == 204 {
                // use the image placeholder
                let empty = anonymousCardCover
                UIHelper.onMainThread {
                    forImageView.image = empty
                }
                LruCache.instance.saveCardCoverImage(cid, size:ofSize, image:empty )
            } else {
                DebugLogger.instance.append( function: "handleFetch()", message:"Failed to get image from server \(fail.message)" )
            }
        } else {
            let cover = UIImage( data: data! )
            UIHelper.onMainThread {
                forImageView.image = cover
            }
            LruCache.instance.saveCardCoverImage(cid, size:ofSize, image:cover! )
        }
    }
  
    // Downsizes the image if necessary, so that the shortest side is equal to minSide
    // also fixes orientation so the image appears right side up
    class func resizeImage(_ image:UIImage,minSide:CGFloat) -> UIImage {
        
        let originalSize = image.size
        if image.imageOrientation == UIImageOrientation.up && originalSize.width <= minSide && originalSize.height <= minSide {
            return image
        }

        var ratio:CGFloat
        if originalSize.width > originalSize.height {
            ratio = minSide / originalSize.height
        } else {
            ratio = minSide / originalSize.width
        }
        
        let newSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio )
        let rect = CGRect(x: 0,y: 0,width: newSize.width,height: newSize.height)
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        image.draw(in: rect)
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return normalizedImage!
    }
    
    class func downsize( media:Media, maxSide:CGFloat ) -> CGSize {
        if let width = media.metaFloat(key: "width"), let height = media.metaFloat(key: "height" ) {
            let original = CGSize(width:CGFloat(width),height:CGFloat(height))
            return downsize(original: original, maxSide: 240)
        }
        
        return CGSize(width:100, height:100) // guesstimate, also used for non-JPEG "?" screens
    }
    
    class func downsize(original:CGSize,maxSide:CGFloat) -> CGSize {
        var ratio:CGFloat
        if original.width > original.height {
            ratio = maxSide / original.width
        } else {
            ratio = maxSide / original.height
        }
        
        return CGSize(width: original.width * ratio, height: original.height * ratio )
    }
    
    class func asWidthXHeight( size:CGSize ) -> String {
        return "\(Int(size.width))x\(Int(size.height))"
    }
    
    class func cropImage(_ image:UIImage) -> UIImage {
        var width = image.size.width
        var height = image.size.height
        
        // determine cropping rectangle
        var x:CGFloat = 0
        var y:CGFloat = 0
        if width > height {
            x = (width - height) / CGFloat(2)
            width = height
        } else {
            y = (height - width) / CGFloat(2)
            height = width
        }
        let rect = CGRect(x: x, y: y, width: width ,height: height)

        // create new image
        let ref = image.cgImage!.cropping(to: rect )!
        let cropped = UIImage(cgImage:ref, scale: image.scale, orientation:image.imageOrientation)
        
        return cropped
    }
}
