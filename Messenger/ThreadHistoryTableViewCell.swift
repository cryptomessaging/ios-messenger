import UIKit

class ThreadHistoryTableViewCell: UITableViewCell {
    
    static let TABLE_CELL_IDENTIFIER = "ThreadHistoryTableViewCell"

    @IBOutlet weak var timeField: UILabel!
    @IBOutlet weak var subjectField: UILabel!
    @IBOutlet weak var messageField: UILabel!
    @IBOutlet weak var threadImage: UIImageView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String!) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    func refresh( _ thread: CachedThread ) {
        if let time = TimeHelper.asDate( thread.updated ) {
            timeField.text = TimeHelper.asPrettyDate(time)
        } else {
            timeField.text = nil
        }
        subjectField.text = thread.subject
        
        ImageHelper.round( threadImage )
        
        // show image of last message poster
        threadImage.image = nil     // clear until new one loads
        let tid = thread.tid!
        if let msg = thread.msg {

            let cid = msg.cid!
            ImageHelper.fetchThreadCardCoverImage(tid, cid:cid, ofSize:UIConstants.CardCoverSize, forImageView:threadImage)
            
            messageField.text = nil // zero out until value is known
            CardHelper.fetchThreadCard(tid, cid:cid ) {
                card in
                DispatchQueue.main.async(execute: {
                    self.setMessage(card.nickname!, msg:thread.msg)
                })
            }
        } else {
            // no messages yet
            messageField.text = "No messages yet".localized
            
            // simply show any person in thread
            if let cids = StringHelper.asArray(thread.cids) {
                if( !cids.isEmpty ) {
                    ImageHelper.fetchThreadCardCoverImage(tid, cid: cids[0], ofSize:UIConstants.CardCoverSize, forImageView:threadImage)
                }
            }
        }
    }
    
    fileprivate func setMessage(_ from:String,msg:LatestChatMessage?) {
        if let body = msg?.body {
            let message = "\(from): \(body)"
            messageField.text = message
        }
    }
}
