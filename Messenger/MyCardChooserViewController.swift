import UIKit

class MyCardChooserViewController: UITableViewController {
    
    fileprivate var cards:[Card]!
    fileprivate var cardSelectedCallback:((_ card:Card)->Void)!
    fileprivate var dismissToUnwind = false
    
    //
    // MARK: Helper methods to launch chooser
    //
    
    class func showCardChooser(_ parent:UIViewController, cards:[Card], completion:@escaping (Card)->Void ) {
        let storyboard: UIStoryboard = UIStoryboard(name: "MyCardChooser", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MyCardChooserViewController") as! MyCardChooserViewController
        vc.cardSelectedCallback = completion
        vc.cards = cards
        
        if let nav = parent.navigationController {
            nav.pushViewController(vc, animated: true )
        } else {
            vc.dismissToUnwind = true
            
            let nav = UINavigationController(rootViewController: vc)
            parent.present(nav, animated: true )
        }
    }
    
    //
    // MARK: Properties
    //
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .selectMyCard, vc:self )
    }
    
    //
    // MARK: Navigation
    //
    
    @IBAction func cancel(_ sender: AnyObject) {
        unwind()
    }
    
    fileprivate func unwind() {
        if dismissToUnwind {
            self.dismiss(animated: true, completion: nil)
        } else {
            _ = navigationController?.popViewController(animated: true)
        }
    }
    
    //
    // MARK: Table handling
    //
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cards.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CardChooserViewCell", for: indexPath) as! CardChooserViewCell
        
        let card = cards[indexPath.row]
        cell.nicknameLabel.text = card.nickname
        cell.taglineLabel.text = card.tagline
        
        ImageHelper.round(cell.coverImage!)
        ImageHelper.fetchCardCoverImage(card.cid!, ofSize:UIConstants.CardCoverSize, forImageView: cell.coverImage!)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let card = cards[indexPath.row]
        
        // make this one our preference
        MyUserDefaults.instance.setDefaultCardId(card.cid)
        
        cardSelectedCallback(card)
        
        // we are done here :)
        unwind()
    }
}
