import Foundation

class SimpleProgressIndicator: UIView, StatusCallback {
    
    fileprivate var label:UILabel?
    fileprivate var startTime:Int64?
    fileprivate var stopped = false
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init(parent:UIView, message:String) {
        var size = parent.frame.height
        if size > UIConstants.RowHeight {
            size = UIConstants.RowHeight
        }

        super.init(frame: CGRect(x: 3, y: 0, width: size, height: size))
        backgroundColor = UIColor(white: 1.0, alpha: 0.8)
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        activityIndicator.frame = CGRect(x: 0, y: 0, width: size, height: size)
        activityIndicator.startAnimating()
        addSubview(activityIndicator)
        
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

