//
//  ViewController.swift
//  viiv_camera_filter
//
//  Created by QuocHuynh on 10/19/21.
//

import UIKit
import AVFoundation
import MetalKit

class ViewController: UIViewController {
    //MARK:- Vars
    var captureSession : AVCaptureSession!
    
    var backCamera : AVCaptureDevice!
    var frontCamera : AVCaptureDevice!
    var backInput : AVCaptureInput!
    var frontInput : AVCaptureInput!
    
    var videoOutput : AVCaptureVideoDataOutput!
    
    var takePicture = false
    var backCameraOn = true
    
    //metal
    var metalDevice : MTLDevice!
    var metalCommandQueue : MTLCommandQueue!
    
    //core image
    var ciContext : CIContext!
    
    var currentCIImage : CIImage?
    
    var mBound : CGRect!
    
    let fadeFilter = CIFilter(name: "CIPhotoEffectFade")
    let sepiaFilter = CIFilter(name: "CISepiaTone")
    let gaussianBlur = CIFilter(name: "CIGaussianBlur")
    let testFilter = CIFilter(name: "CIBloom")
    
    
    
    //MARK:- View Components
    let switchCameraButton : UIButton = {
        let button = UIButton()
        button.backgroundColor = .red
        button.tintColor = .red
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let flashCameraButton : UIButton = {
        let button = UIButton()
        button.backgroundColor = .green
        button.tintColor = .green
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let captureImageButton : UIButton = {
        let button = UIButton()
        button.backgroundColor = .white
        button.tintColor = .white
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    
    let mtkView = MTKView()
    
    //MARK:- Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkPermissions()
        setupMetal()
        setupCoreImage()
        setupAndStartCaptureSession()
    }
    
    //MARK:- Camera Setup
    func setupAndStartCaptureSession(){
        DispatchQueue.global(qos: .userInitiated).async{
            //init session
            self.captureSession = AVCaptureSession()
            //start configuration
            self.captureSession.beginConfiguration()
            
            //session specific configuration
            if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
            }
            self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
            
            //setup inputs
            self.setupInputs()
            
            //setup output
            self.setupOutput()
            
            //commit configuration
            self.captureSession.commitConfiguration()
            //start running it
            self.captureSession.startRunning()
        }
    }
    func stopCaptureSession(){
        
    }
    
    func setupInputs(){
        //get back camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = device
        } else {
            //handle this appropriately for production purposes
            fatalError("no back camera")
        }
        
        //get front camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = device
        } else {
            fatalError("no front camera")
        }
        
        //now we need to create an input objects from our devices
        guard let bInput = try? AVCaptureDeviceInput(device: backCamera) else {
            fatalError("could not create input device from back camera")
        }
        backInput = bInput
        if !captureSession.canAddInput(backInput) {
            fatalError("could not add back camera input to capture session")
        }
        
        guard let fInput = try? AVCaptureDeviceInput(device: frontCamera) else {
            fatalError("could not create input device from front camera")
        }
        frontInput = fInput
        if !captureSession.canAddInput(frontInput) {
            fatalError("could not add front camera input to capture session")
        }
        
        //connect back camera input to session
        captureSession.addInput(backInput)
    }
    
    func setupOutput(){
        videoOutput = AVCaptureVideoDataOutput()
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            fatalError("could not add video output")
        }
        
        videoOutput.connections.first?.videoOrientation = .portrait
    }
    
    func switchCameraInput(){
        //don't let user spam the button, fun for the user, not fun for performance
        switchCameraButton.isUserInteractionEnabled = false
        
        //reconfigure the input
        captureSession.beginConfiguration()
        if backCameraOn {
            captureSession.removeInput(backInput)
            captureSession.addInput(frontInput)
            backCameraOn = false
        } else {
            captureSession.removeInput(frontInput)
            captureSession.addInput(backInput)
            backCameraOn = true
        }
        
        //deal with the connection again for portrait mode
        videoOutput.connections.first?.videoOrientation = .portrait
        
        //mirror video if front camera
        videoOutput.connections.first?.isVideoMirrored = !backCameraOn
        
        //commit config
        captureSession.commitConfiguration()
        
        //acitvate the camera button again
        switchCameraButton.isUserInteractionEnabled = true
    }
    
    //MARK:- Metal
    func setupMetal(){
        //fetch the default gpu of the device (only one on iOS devices)
        metalDevice = MTLCreateSystemDefaultDevice()
        
        //tell our MTKView which gpu to use
        mtkView.device = metalDevice
        
        //tell our MTKView to use explicit drawing meaning we have to call .draw() on it
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = false
        
        //create a command queue to be able to send down instructions to the GPU
        metalCommandQueue = metalDevice.makeCommandQueue()
        
        //conform to our MTKView's delegate
        mtkView.delegate = self
        
        //let it's drawable texture be writen to
        mtkView.framebufferOnly = false
    }
    
    //MARK:- Core Image
    func setupCoreImage(){
        ciContext = CIContext(mtlDevice: metalDevice)
        setupFilters()
    }
    
    //MARK: Filters
    func setupFilters(){
        sepiaFilter?.setValue(NSNumber(value: 1), forKeyPath: "inputIntensity")
        gaussianBlur?.setValue(NSNumber(value: 20), forKeyPath: "inputRadius")
        
        testFilter?.setValue(NSNumber(value: 20), forKeyPath: "inputRadius")
        testFilter?.setValue(NSNumber(value: 1.5), forKeyPath: "inputIntensity")
        
    }
    
    func applyFilters(inputImage image: CIImage) -> CIImage? {
        var filteredImage : CIImage?
        
        // apply filters
        //        sepiaFilter?.setValue(image, forKeyPath: kCIInputImageKey)
        //        filteredImage = sepiaFilter?.outputImage
        
        //        fadeFilter?.setValue(image, forKeyPath: kCIInputImageKey)
        //        filteredImage = fadeFilter?.outputImage
        //
        //        gaussianBlur?.setValue(image, forKeyPath: kCIInputImageKey)
        //        filteredImage = gaussianBlur?.outputImage
        
        testFilter?.setValue(image, forKeyPath: kCIInputImageKey)
        filteredImage = testFilter?.outputImage
        
        return filteredImage
    }
    
    //MARK:- Actions
    @objc func captureImage(_ sender: UIButton?){
        takePicture = true
    }
    
    @objc func switchCamera(_ sender: UIButton?){
        switchCameraInput()
    }
    
    @objc func flashCamera(_ sender: UIButton?){
        if(backCameraOn){
            guard let device = AVCaptureDevice.default(for: .video) else { return }
                if device.hasTorch {
                    do {
                        try device.lockForConfiguration()

                        if device.torchMode == .off {
                            device.torchMode = .on
                        } else {
                            device.torchMode = .off
                        }

                        device.unlockForConfiguration()
                    } catch {
                        print("Torch could not be used")
                    }
                } else {
                    print("Torch is not available")
                }
        }
      
    }
}



