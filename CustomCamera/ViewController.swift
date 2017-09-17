//
//  ViewController.swift
//  CustomCamera
//
//  Created by Sandeep Reddy Areddy on 9/16/17.
//  Copyright © 2017 Sandeep Reddy Areddy. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var previewView: PreviewView!
    private let session = AVCaptureSession()
    var captureDevice: AVCaptureDevice?
    var capturePhotoOutput: AVCapturePhotoOutput?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private let photoOutput = AVCapturePhotoOutput()
    
    let kExposureDurationPower: Float = 5; // Higher numbers will give the slider more sensitivity at shorter durations
    let kExposureMinimumDuration: Float = 1.0/1000; // Limit exposure duration to a useful range
    
    struct Config {
        var ISO: Float {
            
            willSet {
                print("About to set ISO to:  \(newValue)")
            }
            
            didSet {
                if ISO != oldValue {
                    
                }
            }
        }
        var shutterSpeed: Double {
            
            willSet {
                print("About to set ShutterSpeed to:  \(newValue)")
            }
            
            didSet {
                if shutterSpeed != oldValue {
                    
                }
            }
        }
    }
    // Initialize with default values
    var config = Config(ISO: 100.0, shutterSpeed: 320.0)
        
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.checkCameraAuthorization { isAuthorised in
            if isAuthorised {
                // Proceed to set up and use the camera.
                
                self.captureDevice = self.defaultDevice()
                do {
                    self.config.ISO = AVCaptureISOCurrent
                    self.config.shutterSpeed = Double(self.kExposureMinimumDuration)
                    self.session.sessionPreset = AVCaptureSessionPresetPhoto
                    let input = try AVCaptureDeviceInput(device: self.captureDevice)
                    self.session.addInput(input)
                    self.previewView.session = self.session
                    self.previewView.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
                    self.session.startRunning()
                    self.capturePhotoOutput = AVCapturePhotoOutput()
                    self.capturePhotoOutput?.isHighResolutionCaptureEnabled = true
                    // Set the output on the capture session
                    self.session.addOutput(self.capturePhotoOutput)
                    self.session.commitConfiguration()
                } catch {
                    print(error)
                }
                
//                print(self.capturePhotoOutput?.availableRawPhotoPixelFormatTypes)
            } else {
                
                print("Permission to use camera denied.")
                
            }
        }
    }

    func defaultDevice() -> AVCaptureDevice {
        if let device = AVCaptureDevice.defaultDevice(withDeviceType: .builtInDualCamera,
                                                      mediaType: AVMediaTypeVideo,
                                                      position: .back) {
            return device // use dual camera on supported devices
        } else if let device = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera,
                                                             mediaType: AVMediaTypeVideo,
                                                             position: .back) {
            return device // use default back facing camera otherwise
        } else {
            fatalError("All supported devices are expected to have at least one of the queried capture devices.")
        }
    }
    
    func checkCameraAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
        
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
            
        case .authorized:
            
            //The user has previously granted access to the camera.
            
            completionHandler(true)
            
        case .notDetermined:
            
            // The user has not yet been presented with the option to grant video access so request access.
            
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { success in
                
                completionHandler(success)
                
            })
            
        case .denied:
            
            // The user has previously denied access.
            
            completionHandler(false)
            
        case .restricted:
            
            // The user doesn't have the authority to request access e.g. parental restriction.
            
            completionHandler(false)
            
        }
        
    }
    // Set exposure with custom ISO & Shutter Speed
    func setExposure() -> Void {
        
        do {
            try self.captureDevice?.lockForConfiguration()
            self.captureDevice?.setExposureModeCustomWithDuration(CMTimeMakeWithSeconds( config.shutterSpeed, 1000*1000*1000 ), iso: config.ISO, completionHandler: { (time) -> Void in
                //
            })
            
            self.captureDevice?.unlockForConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // Capture photo
    @IBAction func capturePhoto(_ sender: Any) {
        // Make sure capturePhotoOutput is valid
        guard self.capturePhotoOutput != nil else { return }
        let formats = self.capturePhotoOutput?.availableRawPhotoPixelFormatTypes
        // Get an instance of AVCapturePhotoSettings class
        let photoSettings: AVCapturePhotoSettings
        if (formats!.count) > 0{
            photoSettings = AVCapturePhotoSettings(rawPixelFormatType:formats?.first as! OSType)
        }else{
            photoSettings = AVCapturePhotoSettings()
        }
        // Set photo settings for our need
        photoSettings.isAutoStillImageStabilizationEnabled = false //Should be false when setting is for Raw format
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = .auto
        // Call capturePhoto method by passing our photo settings and a
        // delegate implementing AVCapturePhotoCaptureDelegate
        self.capturePhotoOutput?.capturePhoto(with: photoSettings, delegate: self)
    }
    
    // ISO slider change event
    @IBAction func setISO(_ sender: UISlider) {
        // Adjust the iso to clamp between minIso and maxIso based on the active format
        let minISO = self.captureDevice!.activeFormat.minISO
        let maxISO = self.captureDevice!.activeFormat.maxISO
        config.ISO = sender.value * (maxISO - minISO) + minISO
        self.setExposure()
    }
    
    // Shutter speed slider change event
    @IBAction func setShutterSpeed(_ sender: UISlider) {
        let p = pow( sender.value, kExposureDurationPower ); // Apply power function to expand slider's low-end range
        
        let minDurationSeconds = max(CMTimeGetSeconds( self.captureDevice!.activeFormat.minExposureDuration ), Float64(kExposureMinimumDuration));
        let maxDurationSeconds = max(CMTimeGetSeconds( self.captureDevice!.activeFormat.maxExposureDuration ), Float64(kExposureMinimumDuration));
        
        let newDurationSeconds = Float64(p) * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds; // Scale from 0-1 slider range to actual duration
        
        config.shutterSpeed = newDurationSeconds
        self.setExposure()
        print("\(newDurationSeconds)")

    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ViewController : AVCapturePhotoCaptureDelegate {
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        // get captured image
        // Make sure we get some photo sample buffer
        guard error == nil,
            let photoSampleBuffer = photoSampleBuffer else {
                print("Error capturing photo: \(String(describing: error))")
                return
        }
        
        // Convert photo same buffer to a jpeg image data by using // AVCapturePhotoOutput
        guard let imageData =
            AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer) else {
                return
        }
        
        // Initialise a UIImage with our image data
        let capturedImage = UIImage.init(data: imageData , scale: 1.0)
        if let image = capturedImage {
            // Save our captured image to photos album
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
    //This is used when output is raw format
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingRawPhotoSampleBuffer rawSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        print("RAw Image")
    }
}
