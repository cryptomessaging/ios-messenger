//
//  ScanConsentViewController.swift
//  Messenger
//
//  Created by Mike Prince on 10/30/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import AVFoundation

class ScanConsentViewController: UIViewController, UITextFieldDelegate {
    
    var kidname:String?
    var parentEmail:String?
    
    var helpButton:UIBarButtonItem!
    
    let captureSession = AVCaptureSession()
    var captureDevice : AVCaptureDevice?
    var previewLayer : AVCaptureVideoPreviewLayer?
    let stillImageOutput = AVCaptureStillImageOutput()
    
    class func showScanConsent(_ nav:UINavigationController,kidname:String,parentEmail:String) {
        let vc = ScanConsentViewController()
        vc.kidname = kidname
        vc.parentEmail = parentEmail
        nav.pushViewController( vc, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup navigation bar
        edgesForExtendedLayout = UIRectEdge()

        helpButton = UIBarButtonItem(title: "Scan Consent Help".localized, style: .plain, target: self, action: #selector(helpButtonAction))
        helpButton.isEnabled = false
        navigationItem.rightBarButtonItem = helpButton
        
        // Do any additional setup after loading the view, typically from a nib.
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        let devices = AVCaptureDevice.devices()
        
        // Loop through all the capture devices on this phone
        for device in devices! {
            // Make sure this particular device supports video
            if ((device as AnyObject).hasMediaType(AVMediaTypeVideo)) {
                // Finally check the position and confirm we've got the back camera
                if((device as AnyObject).position == AVCaptureDevicePosition.back) {
                    captureDevice = device as? AVCaptureDevice
                    if captureDevice != nil {
                        //print("Capture device found")
                        self.beginSession()
                    }
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .scanConsent, vc:self )
        helpButtonAction( helpButton )
    }
    
    func helpButtonAction(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: nil, message: "Center the form you just signed in this camera window, and then tap anywhere on the screen to scan it".localized, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK".localized, style: .default, handler:nil )
        alertController.addAction(OKAction)
        
        present(alertController, animated: true, completion: nil )
    }
    
    //===========
    
    func beginSession() {
        let input:AVCaptureInput?
        do {
            input = try AVCaptureDeviceInput(device: captureDevice)
        } catch _ {
            print("Failed to begin camera session")
            return
        }
        
        captureSession.addInput( input )
        
        if let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession) {
            previewLayer.bounds = view.bounds
            previewLayer.position = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            let cameraPreview = UIView(frame: CGRect(x: 0.0, y: 0.0, width: view.bounds.size.width, height: view.bounds.size.height))
            cameraPreview.layer.addSublayer(previewLayer)
            cameraPreview.addGestureRecognizer(UITapGestureRecognizer(target: self, action:#selector(saveToCamera)))
            view.addSubview(cameraPreview)
        }
        
        captureSession.startRunning()
        
        stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecJPEG]
        if captureSession.canAddOutput(stillImageOutput) {
            captureSession.addOutput(stillImageOutput)
        }
    }
    
    func saveToCamera(_ sender: UITapGestureRecognizer) {
        if let videoConnection = stillImageOutput.connection(withMediaType: AVMediaTypeVideo) {
            stillImageOutput.captureStillImageAsynchronously(from: videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                let jpeg = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                self.processImage( jpeg! )
            }
        }
    }
    
    func processImage(_ jpeg:Data) {
        let progress = ProgressIndicator(parent:view, message:"Uploading (Consent) Form".localized)
        //nextButton.enabled = false
        
        // base64 encode image
        let base64 = jpeg.base64EncodedString(options: NSData.Base64EncodingOptions.lineLength76Characters)
        let size = base64.lengthOfBytes(using: String.Encoding.utf8)
        DebugLogger.instance.append( function: "processImage()", message:"Base64 encoded image is \(size) bytes")
        
        // craft new card
        let parentConsent = ParentConsent()
        parentConsent.kidname = self.kidname
        parentConsent.parentEmail = self.parentEmail
        parentConsent.media = "data:image/jpeg;base64,\(base64)"
        
        let progressHandler: (_ totalSent: Int64, _ uploadSize: Int64) -> () = {
            totalSent, uploadSize in
            
            let percent = Int( Float(totalSent) / Float(uploadSize) * 100 )
            let msg = String( format:"Uploading (Consent Form) %d%%".localized, percent )
            progress.onStatus( msg )
        }
        
        MobidoRestClient.instance.sendParentConsent(parentConsent, progressHandler:progressHandler ) {
            result in
            
            DispatchQueue.main.async(execute: {
                progress.stop()
                
                // if successful...
                if ProblemHelper.showProblem(self, title: "Failed to Upload (Consent) Form".localized, failure: result.failure) {
                    //self.nextButton.enabled = true
                } else {
                    // success!!
                    AnalyticsHelper.trackResult(.parentConsented)
                    ConsentFinishedViewController.showConsentFinished(self.navigationController!)
                }
            })
        }
    }
}
