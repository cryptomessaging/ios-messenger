import Foundation
import UIKit

protocol OnCardSelectedCallback: class {
    func onCardSelected(_ sender:NSObject, card:Card, color:UIColor)
}

class CardScrollerView<CardViewT:UIView>: UICollectionView, UICollectionViewDelegate, UICollectionViewDataSource where CardViewT:CardPresenter {
    
    fileprivate var tid:String?
    fileprivate let sizingCell = CardViewT()
    weak var cardSelectedCallback:OnCardSelectedCallback?
    fileprivate var isSimpleTheme = false
    fileprivate var selectedCardId:String?
    
    init(frame: CGRect ) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = sizingCell.cellSize()
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets.zero
        super.init(frame: frame, collectionViewLayout:layout )
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init( coder: aDecoder )
        commonInit()
    }
    
    fileprivate func commonInit() {
        isSimpleTheme = ThemeHelper.isSimpleTheme()
        self.autoresizingMask = UIViewAutoresizing()
        self.translatesAutoresizingMaskIntoConstraints = false
        register(UICollectionViewCell.self, forCellWithReuseIdentifier: "card-cell" )
        self.dataSource = self
        self.delegate = self
        self.backgroundColor = UIColor.white
    }
    
    func setSelectedCardId(_ cid:String?) {
        selectedCardId = cid
        reloadData()
    }
    
    func setCards( _ cards:[Card], tid:String? ) {
        self.tid = tid
        self.cards = cards
        reloadData()
    }
    
    @discardableResult func addCard(_ card:Card) -> UIColor {
        // make sure card isnt already there
        if CardHelper.findCard( card.cid, inCards: cards ) == nil {
            if( card.isBot() ) {
                cards.insert( card, at: 0 )
            } else {
                cards.append(card)
            }
            reloadData()
        }
        
        return getCardColor(card)
    }
    
    //
    // MARK: Data source
    //

    fileprivate(set) var cards = [Card]()
    
    func collectionView( _ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cards.count
    }
    
    func collectionView( _ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = dequeueReusableCell(withReuseIdentifier: "card-cell", for: indexPath) //{
        let subviews = cell.contentView.subviews
        var cardView:CardViewT
        if subviews.count == 0 {
            cardView = CardViewT()
            cell.contentView.addSubview(cardView)
        } else {
            cardView = subviews[0] as! CardViewT
        }
        
        let i = indexPath.row
        let card = cards[i]
        
        // color the bots
        var color = UIColor.clear
        if isSimpleTheme {
            if card.cid == selectedCardId {
                color = ThemeHelper.themeColor()
            }
        } else {
            color = getCardColor(card)
        }
        
        cardView.setCard(card, tid:tid, color:color.cgColor )
        return cell
    }
    
    func getCardColor(_ card:Card) -> UIColor {
        if card.isBot() {
            let (before,total) = countBots(card)
            return UIHelper.cardColor(before, range: total )
        } else {
            return UIColor.clear
        }
    }
    
    // how many bots before this one, how many total?
    func countBots(_ card:Card) -> (before:Int,total:Int) {
        var total = 0
        var before = 0
        var found = false
        for c in cards {
            if c.isBot() {
                total += 1

                if c.cid == card.cid {
                    found = true
                }
                
                if !found {
                    before += 1 // count bots before our card is found
                }
            }
        }
        
        return (before,total)
    }
    
    //
    // MARK: Handle list interaction
    //
    
    func collectionView( _ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let card = cards[indexPath.row]
        let color = getCardColor(card)
        cardSelectedCallback?.onCardSelected(self,card:card,color:color)
    }
}
