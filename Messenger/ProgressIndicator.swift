import Foundation

class ProgressIndicator: UIView, StatusCallback {
    
    fileprivate var label:UILabel?
    fileprivate var startTime:Int64?
    fileprivate var stopped = false
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init(parent:UIView, message:String) {
        super.init(frame: CGRect(x: parent.frame.midX - 120, y: parent.frame.midY - 25 , width: 240, height: 50))
        layer.cornerRadius = 15
        backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.white)
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        activityIndicator.startAnimating()
        addSubview(activityIndicator)
        
        label = UILabel(frame: CGRect(x: 50, y: 0, width: 190, height: 50))
        label!.text = message
        label!.textColor = UIColor.white
        addSubview(label!)
        
        // always delay 0.2 seconds
        UIHelper.delay(0.2) {
            if !self.stopped {
                parent.addSubview(self)
                self.startTime = TimeHelper.getMillis()
            }
        }
    }
    
    func stop() {
        stopped = true
        
        // make sure we are on main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.stop()
            }
            return
        }
        
        if let start = startTime {
            // how long has the spinner been running?
            let duration = TimeHelper.getMillisDurationSince(start)
            if duration > 1000 {
                removeFromSuperview()
            } else {
                // artificially keep it spinning a bit longer
                let delay = 1000 - duration
                UIHelper.delay(Double(delay) / 1000) {
                    self.removeFromSuperview()
                }
            }
        }
    }
    
    func onStatus(_ message: String) {
        // make sure this happens in the UI thread
        DispatchQueue.main.async {
            self.label!.text = message
        }
    }
}
