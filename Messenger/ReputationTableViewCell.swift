import Foundation
import UIKit

class ReputationTableViewCell: UITableViewCell {
    
    let label = UILabel()
    let value = UITextView()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init( style: style, reuseIdentifier: reuseIdentifier )
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
        commonInit()
    }
    
    fileprivate func commonInit() {
        label.font = UIFont.boldSystemFont(ofSize: 17)
        label.textAlignment = .right
        contentView.addSubview( label)
        
        value.font = UIFont.systemFont(ofSize: 17)
        value.isUserInteractionEnabled = true
        value.isScrollEnabled = false
        value.isEditable = false
        value.isSelectable = true
        value.dataDetectorTypes = .all
        value.textContainerInset = UIEdgeInsetsMake(0,0,0,0)
        contentView.addSubview( value )
    }
    
    func setReputation( _ reputation:Reputation, labelWidth:CGFloat, margin:CGFloat, valueWidth:CGFloat ) -> CGFloat {
        label.text = reputation.label
        let height1 = fit( label, x:0, width:labelWidth)
        let x = labelWidth + margin
        value.text = reputation.value
        let height2 = fit( value, x:x, width:valueWidth)
        
        let width = labelWidth + margin + valueWidth
        let height = max(height1, height2)
        frame = CGRect(x: 0,y: 0,width: width,height: height)
        return height + margin
    }
    
    fileprivate func fit( _ label:UIView, x:CGFloat, width:CGFloat ) -> CGFloat {
        let size = label.sizeThatFits( CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        label.frame = CGRect(x: x, y: 0, width: width, height: size.height)
        return size.height
    }
}
