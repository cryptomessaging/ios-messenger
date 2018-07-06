import UIKit

class FullCardView: UIView, UITableViewDelegate, UITableViewDataSource {
    
    fileprivate var card:Card?
    
    @IBOutlet weak var cardCanvas: UIView!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var reputationTable: UITableView!
    @IBOutlet weak var taglineLabel: UILabel!
    
    fileprivate var labelWidth:CGFloat = 0
    fileprivate var valueWidth:CGFloat = 0
    fileprivate var reputationTableHeightConstraint:NSLayoutConstraint?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        coverImageView.layer.cornerRadius = 10
        coverImageView.clipsToBounds = true
        
        // reputation table
        reputationTable.register(ReputationTableViewCell.self, forCellReuseIdentifier: "cell")
        reputationTable.delegate = self
        reputationTable.dataSource = self
        reputationTable.isScrollEnabled = false
        
        reputationTableHeightConstraint = NSLayoutConstraint(item: reputationTable, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 0)
    }
    
    func setCard( _ card:Card, tid:String? ) {
        self.card = card
        
        if let tid = tid {
            ImageHelper.fetchThreadCardCoverImage(tid, cid: card.cid!, ofSize: UIConstants.CardCoverSize, forImageView: coverImageView )
        } else {
            ImageHelper.fetchCardCoverImage(card.cid!, ofSize: UIConstants.CardCoverSize, forImageView: coverImageView )
        }
        
        nicknameLabel.text = card.nickname
        taglineLabel.text = card.tagline
        
        updateReputationTableHeight()
        reputationTable.reloadData()
    }
    
    fileprivate func getReputation(_ indexPath:IndexPath) -> Reputation {
        return card!.reputations![indexPath.row]
    }
    
    fileprivate func updateReputationTableHeight() {
        
        // easy case of no reputations?
        guard let reputations = card?.reputations else {
            reputationTableHeightConstraint?.constant = 0
            return
        }
        
        // TODO what's the better way to find width?
        let screenSize: CGRect = UIScreen.main.bounds
        let tableWidth = screenSize.width - 32
        
        let sizes = FullCardView.findReputationTableSizes( tableWidth, reputations:reputations )
        labelWidth = sizes.labelWidth
        valueWidth = sizes.valueWidth
        
        reputationTableHeightConstraint?.constant = sizes.height
    }
    
    //
    // MARK: Sizing, must be called from main thread, NOT thread safe
    //
    
    fileprivate static let margin:CGFloat = 8
    fileprivate static let sizingCell = ReputationTableViewCell()
    
    class func findSize( _ card:Card, width:CGFloat ) -> CGSize {
        let topMargin:CGFloat = 16
        let imageHeight:CGFloat = 100
        let bottomMargin:CGFloat = 16
        var reputationHeight:CGFloat = 0
        if let reps = card.reputations {
            reputationHeight = findReputationTableSizes( width, reputations: reps ).height
        }
        
        let height = topMargin + imageHeight + reputationHeight + bottomMargin
        return CGSize( width: width, height: height )
    }
    
    class func findReputationTableSizes(_ tableWidth:CGFloat, reputations:[Reputation]) -> (height:CGFloat, labelWidth:CGFloat, valueWidth:CGFloat) {
        let labelWidth = findMaxLabelWidth((tableWidth - margin) / 2, reputations:reputations)
        let valueWidth = tableWidth - margin - labelWidth
        
        var height:CGFloat = 0
        for r in reputations {
            height += FullCardView.sizingCell.setReputation( r, labelWidth:labelWidth, margin:margin, valueWidth:valueWidth )
        }
        
        return (height,labelWidth,valueWidth)
    }
    
    class func findMaxLabelWidth( _ width:CGFloat, reputations:[Reputation] ) -> CGFloat {
        let sizingLabel = FullCardView.sizingCell.label
        var max:CGFloat = 0
        for r in reputations {
            if let label = r.label {
                sizingLabel.text = label
                let size = sizingLabel.sizeThatFits( CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
                if size.width > max {
                    max = size.width
                }
            }
        }
        
        return max
    }
    
    //
    // MARK: Reputation table datasource
    //
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let reps = card?.reputations {
            return reps.count
        } else {
            return 0
        }
    }
    
    fileprivate var heightConstraintAdded = false
    func tableView( _ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        // Hack.  Adding constraints in setCard() was giving "Unable to install constraint on view.  Does the constraint reference
        // something from outside the subtree of the view?"  So we wait a wee bit until things have settled and then add
        // the constraint.  Sigh.
        if !heightConstraintAdded {
            addConstraint( reputationTableHeightConstraint! )
            heightConstraintAdded = true
        }
        return FullCardView.sizingCell.setReputation( getReputation(indexPath), labelWidth:labelWidth, margin:FullCardView.margin, valueWidth:valueWidth )
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = reputationTable.dequeueReusableCell(withIdentifier: "cell") as! ReputationTableViewCell
        _ = cell.setReputation( getReputation(indexPath), labelWidth:labelWidth, margin:FullCardView.margin, valueWidth:valueWidth )
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //print("boing!")
    }
}
