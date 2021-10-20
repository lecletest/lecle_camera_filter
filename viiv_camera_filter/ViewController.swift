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

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //try and get a CVImageBuffer out of the sample buffer
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        //get a CIImage out of the CVImageBuffer
        let ciImage = CIImage(cvImageBuffer: cvBuffer)
        
        //filter it
        guard let filteredCIImage = applyFilters(inputImage: ciImage) else {
            return
        }
        
        self.currentCIImage = filteredCIImage
        
        mtkView.draw()
        
        //get UIImage out of CIImage
        _ = UIImage(ciImage: filteredCIImage)
        
        if !takePicture {
            
            return //we have nothing to do with the image buffer
        }
        
        DispatchQueue.main.async {
            self.takePicture = false
        }
    }
    
}

extension ViewController : MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        //tells us the drawable's size has changed
    }
    
    func draw(in view: MTKView) {
        //create command buffer for ciContext to use to encode it's rendering instructions to our GPU
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            return
        }
        
        //make sure we actually have a ciImage to work with
        guard var ciImage = currentCIImage else {
            return
        }
        
        //make sure the current drawable object for this metal view is available (it's not in use by the previous draw cycle)
        guard let currentDrawable = view.currentDrawable else {
            return
        }
        
        //make sure frame is centered on screen
        //        let heightOfciImage = ciImage.extent.height
        //        let heightOfDrawable = view.drawableSize.height
        //        let yOffsetFromBottom = (heightOfDrawable - heightOfciImage)/2
        
        
        guard var  r = mBound else{
            return
        }
        r.size = view.drawableSize
        let scaleX = r.size.height/ciImage.extent.size.height
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleX)
        ciImage = ciImage.transformed(by: transform)
        ciImage = ciImage.cropped(to: r)
        let x = -r.origin.x
        let y = -r.origin.y
        
        
        
        //render into the metal texture
        self.ciContext.render(ciImage,
                              to: currentDrawable.texture,
                              commandBuffer: commandBuffer,
                              bounds: CGRect(origin: CGPoint(x: x, y: y), size: r.size),
                              //                          bounds: CGRect(origin: CGPoint(x: 0, y: -yOffsetFromBottom), size: view.drawableSize),
                              colorSpace: CGColorSpaceCreateDeviceRGB())
        
        //register where to draw the instructions in the command buffer once it executes
        commandBuffer.present(currentDrawable)
        //commit the command to the queue so it executes
        commandBuffer.commit()
    }
}

extension ViewController {
    //MARK:- View Setup
    func setupView(){
        view.backgroundColor = .black
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mtkView)
        view.addSubview(switchCameraButton)
        view.addSubview(captureImageButton)
        view.addSubview(flashCameraButton)

        
        NSLayoutConstraint.activate([
            switchCameraButton.widthAnchor.constraint(equalToConstant: 30),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 30),
            switchCameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            switchCameraButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            
            flashCameraButton.widthAnchor.constraint(equalToConstant: 30),
            flashCameraButton.heightAnchor.constraint(equalToConstant: 30),
            flashCameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            flashCameraButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -80),
            
            captureImageButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            captureImageButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            captureImageButton.widthAnchor.constraint(equalToConstant: 50),
            captureImageButton.heightAnchor.constraint(equalToConstant: 50),
            
            
            mtkView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mtkView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mtkView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mtkView.topAnchor.constraint(equalTo: view.topAnchor)
        ])
        
        switchCameraButton.addTarget(self, action: #selector(switchCamera(_:)), for: .touchUpInside)
        captureImageButton.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        flashCameraButton.addTarget(self, action: #selector(flashCamera(_:)), for: .touchUpInside)
        
        mBound = mtkView.bounds
    }
    
    //MARK:- Permissions
    func checkPermissions() {
        let cameraAuthStatus =  AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch cameraAuthStatus {
        case .authorized:
            return
        case .denied:
            abort()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler:
                                                { (authorized) in
                if(!authorized){
                    abort()
                }
            })
        case .restricted:
            abort()
        @unknown default:
            fatalError()
        }
    }
}
