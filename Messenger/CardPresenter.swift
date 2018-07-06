import UIKit

protocol CardPresenter {
    func setCard( _ card:Card, tid:String?, color:CGColor )
    func cellSize() -> CGSize
}
