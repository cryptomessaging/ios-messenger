import Foundation
import Chatto

/*
 * Puts message in local db/cache and tries to send to remote chat server
 * Each message sender is bound to one thread
 * Calls onMessageChanged when any changes are made to the database
 */
open class MessageSender {
    
    fileprivate var tid:String?
    
    func reset(_ tid:String) {
        self.tid = tid
    }
    
    func sendMessage(_ msg:ChatMessage,image:UIImage?) {
        msg.tid = tid
        
        // A *very* short term cache of the media so the chat message presenter can show the image
        // NOTE, the timestamp, which is used for caching will change, so this entry is only good for a few seconds :(
        if let image = image {
            let size = PhotoMessageBubbleView.bestMediaPreviewSize(media: msg.media![0])
            LruCache.instance.saveChatImage(msg, index:0, size:size, image:image )
        }
        
        do {
            try ChatDatabase.instance.addMessage(msg,status:MessageHelper.asString(.sending))
        } catch {
            DebugLogger.instance.append( function: "sendMessage()", error:error )
            // fall through, when message is APNd back, we can try to put in database again
        }

        // send to remote server
        MobidoRestClient.instance.sendChatMessage( msg.tid!, message:msg ) {
            result in
            
            let oldCreated = msg.created!
            let newStatus:MessageStatus
            if result.failure != nil {
                newStatus = .failed
                // keep old value .created value
            } else {
                newStatus = .success
                msg.created = result.created!
                
                AnalyticsHelper.trackResult(.textSent)
            }
            
            // update database
            // NOTE the database update will signal a notify for UIs to update
            do {
                try ChatDatabase.instance.updateMessage( msg.tid!, from:msg.from!, oldCreated:oldCreated, newCreated:msg.created!, newStatus:MessageHelper.asString(newStatus))
            } catch {
                DebugLogger.instance.append( function: "sendMessage():updateMessage", error:error )
            }
        }
    }
}
