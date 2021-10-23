//
//  ViewController.swift
//  viiv_camera_filter
//
//  Created by QuocHuynh on 10/19/21.
//

import UIKit
import AVFoundation
import MetalKit
import Photos

class ViewController: UIViewController {
    
    //MARK:- Vars
    let captureSession = AVCaptureSession()
    
    
    var audioDataOutput : AVCaptureAudioDataOutput!
    var videoDataOutput : AVCaptureVideoDataOutput!
    var backCamera : AVCaptureDevice!
    var frontCamera : AVCaptureDevice!
    var backInput : AVCaptureInput!
    var frontInput : AVCaptureInput!
    
    var takePicture = false
    var backCameraOn = true
    
    //metal
    var metalDevice : MTLDevice!
    var metalCommandQueue : MTLCommandQueue!
    
    //core image
    var ciContext : CIContext!
    var currentCIImage : CIImage?
    
    
    var mVideoBound : CGRect!
    
    var currentFilter = CIFilter(name: "CIPhotoEffectFade")
    let mtkView = MTKView()
    
    lazy var supportedFilters = ["CIMedianFilter",
                                 "CIMotionBlur",
                                 "CILinearToSRGBToneCurve",
                                 "CISRGBToneCurveToLinear",
                                 "CITemperatureAndTint",
                                 "CIColorInvert",
                                 "CIColorMonochrome",
                                 "CIColorPosterize",
                                 "CIFalseColor",
                                 "CIMaskToAlpha",
                                 "CIMaximumComponent",
                                 "CIMinimumComponent",
                                 "CIPhotoEffectChrome",
                                 "CIPhotoEffectFade",
                                 "CIPhotoEffectInstant",
                                 "CIPhotoEffectMono",
                                 "CIPhotoEffectNoir",
                                 "CIPhotoEffectProcess",
                                 "CIPhotoEffectTonal",
                                 "CIPhotoEffectTransfer",
                                 "CISepiaTone",
                                 "CIVignetteEffect",
                                 "CICircularWrap",
                                 "CIGlassLozenge",
                                 "CIStretchCrop",
                                 "CITorusLensDistortion",
                                 "CITwirlDistortion",
                                 "CIConstantColorGenerator",
                                 "CIPerspectiveCorrection",
                                 "CILinearGradient",
                                 "CISmoothLinearGradient",
                                 "CICircularScreen",
                                 "CICMYKHalftone",
                                 "CIDotScreen",
                                 "CIHatchedScreen",
                                 "CILineScreen",
                                 "CIComicEffect",
                                 "CICrystallize",
                                 "CIEdges",
                                 "CIEdgeWork",
                                 "CIHeightFieldFromMask",
                                 "CIHexagonalPixellate","CIPixellate",
                                 "CIPointillize",
                                 "CISpotColor",
                                 "CISpotLight","CIKaleidoscope",]
    
    //MARK:- View Components
    let filterPickerView = UIPickerView()
    
    let recordingLabel : UILabel = {
        let label = UILabel()
        label.backgroundColor = .black
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
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
    
    let recordCameraButton : UIButton = {
        let button = UIButton()
        button.backgroundColor = .yellow
        button.tintColor = .yellow
        button.layer.cornerRadius = 25
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
    
    let filterCameraButton : UIButton = {
        let button = UIButton()
        button.backgroundColor = .systemPink
        button.tintColor = .systemPink
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
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
    func setupRecordWriters(){
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddhhmmss"
        let filename = dateFormatter.string(from: Date()).appending(".mp4")
        
        let documentsPath = self.getDocumentsDirectory().path
        self.videoDataOutputFullFileName = documentsPath.appending("/\(filename)")
        
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: self.videoDataOutputFullFileName!) {
            print("WARN:::The file: \(self.videoDataOutputFullFileName!) exists, will delete the existing file")
            do {
                try fileManager.removeItem(atPath: self.videoDataOutputFullFileName!)
            } catch let error as NSError {
                print("WARN:::Cannot delete existing file: \(self.videoDataOutputFullFileName!), error: \(error.debugDescription)")
            }
        } else {
            print("DEBUG:::The file \(self.videoDataOutputFullFileName!) not exists")
        }
        
        if self.videoDataOutputFullFileName == nil {
            print("Error:The video output file name is nil")
            return
        }
        
        //Add video input
        self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: mVideoBound.width,
            AVVideoHeightKey: mVideoBound.height,
            AVVideoCompressionPropertiesKey:[
                AVVideoAverageBitRateKey: self.mtkView.bounds.width * self.mtkView.bounds.height * 10.1
            ]
        ])
        
        self.videoWriterInput?.expectsMediaDataInRealTime = true
        
        //Add audio input
        audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 64000,
        ])
        audioWriterInput?.expectsMediaDataInRealTime = true
        
        
        do {
            self.videoWriter = try AVAssetWriter(outputURL: URL(fileURLWithPath: self.videoDataOutputFullFileName!), fileType: AVFileType.mp4)
        } catch let error as NSError {
            print("ERROR:::::>>>>>>>>>>>>>Cannot init videoWriter, error:\(error.localizedDescription)")
        }
        
        
        let sourcePixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: NSNumber(value: Int32(self.mtkView.bounds.width)),
            kCVPixelBufferHeightKey as String: NSNumber(value: Int32(self.mtkView.bounds.height))
        ]
        
        self.videoWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: self.videoWriterInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        if self.videoWriter!.canAdd(self.videoWriterInput!) {
            self.videoWriter!.add(self.videoWriterInput!)
        } else {
            print("ERROR:::Cannot add videoWriterInput into videoWriter")
        }
        
        
        if self.videoWriter!.canAdd(self.audioWriterInput!) {
            self.videoWriter!.add(self.audioWriterInput!)
        } else {
            print("ERROR:::Cannot add audioWriterInput into videoWriter")
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
        
        //Setup your microphone
        guard let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio) else {
            fatalError("could not create input device from audio")
        }
        
        guard let audioInput =  try? AVCaptureDeviceInput(device: audioDevice) else {
            fatalError("could not create input device from audio")
        }
        
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }else{
            fatalError("could not create input device from audio")
        }
        
        //connect back camera input to session
        captureSession.addInput(backInput)
    }
    
    func setupOutput(){
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [
            (kCVPixelBufferPixelFormatTypeKey as String) : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        
        
        if captureSession.canAddOutput(videoDataOutput) {
            videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
            captureSession.addOutput(videoDataOutput)
        } else {
            fatalError("could not add video output")
        }
        
        audioDataOutput = AVCaptureAudioDataOutput()
        
        if captureSession.canAddOutput(audioDataOutput) {
            audioDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
            captureSession.addOutput(audioDataOutput)
        } else {
            fatalError("could not add audio output")
        }
        
        videoDataOutput.connections.first?.videoOrientation = .portrait
        
        
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
        videoDataOutput.connections.first?.videoOrientation = .portrait
        
        //mirror video if front camera
        videoDataOutput.connections.first?.isVideoMirrored = !backCameraOn
        
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
        mtkView.contentScaleFactor = UIScreen.main.nativeScale
        mtkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mtkView.autoResizeDrawable = true
        
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
    }
    
    func applyFilters(inputImage image: CIImage) -> CIImage? {
        var filteredImage : CIImage?
        // apply image filters
        currentFilter?.setValue(image, forKeyPath: kCIInputImageKey)
        filteredImage = currentFilter?.outputImage
        return filteredImage
    }
    
    //MARK:- Actions
    @objc func captureImage(_ sender: UIButton?){
        takePicture = true
    }
    
    @objc func filterCameraClicked(_ sender: UIButton?){
        let b =  filterPickerView.isHidden
        if(b){
            filterPickerView.isHidden = false
        }else{
            filterPickerView.isHidden = true
        }
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
                        self.flashCameraButton.backgroundColor = .green.withAlphaComponent(0.3)
                    } else {
                        device.torchMode = .off
                        self.flashCameraButton.backgroundColor = .green
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
    
    var recording = false
    var videoDataOutputFullFileName: String?
    
    var videoWriterInput: AVAssetWriterInput?
    var audioWriterInput: AVAssetWriterInput?
    
    var videoWriter: AVAssetWriter?
    
    var videoWriterInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    var frameCounter = 0
    
    let filterContext = CIContext()
    
    
    lazy var lastSampleTime: CMTime = {
        let lastSampleTime = CMTime.zero
        return lastSampleTime
    }()
    
    @objc func recordCamera(_ sender: UIButton?){
        if(!recording){
            self.recordCameraButton.backgroundColor = .yellow.withAlphaComponent(0.3)
            recordingLabel.isHidden = false
            recordingLabel.text = "Recording..."
            self.setupRecordWriters()
            recording = true
            
            if self.videoWriter!.status != AVAssetWriter.Status.writing  {
                print("DEBUG::::::::::::::::The videoWriter status is not writing, and will start writing the video.")
                
                let hasStartedWriting = self.videoWriter!.startWriting()
                if hasStartedWriting {
                    self.videoWriter!.startSession(atSourceTime: self.lastSampleTime)
                    print("DEBUG:::Have started writting on videoWriter, session at source time: \(self.lastSampleTime)")
                    
                } else {
                    print("WARN:::Fail to start writing on videoWriter")
                }
            } else {
                print("WARN:::The videoWriter.status is writting now, so cannot start writing action on videoWriter")
            }
            
        }else{
            self.finishRecordVideo()
            recordingLabel.isHidden = true
            self.recordCameraButton.backgroundColor = .yellow
        }
    }
    
    func finishRecordVideo() {
        self.recording = false
        self.videoWriterInput!.markAsFinished()
        self.videoWriterInputPixelBufferAdaptor = nil
        self.videoWriter!.finishWriting {
            if self.videoWriter!.status == AVAssetWriter.Status.completed {
                print("DEBUG:::The videoWriter status is completed")
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: self.videoDataOutputFullFileName!) {
                    print("DEBUG:::The file: \(self.videoDataOutputFullFileName ?? "path") has been save into documents folder, and is ready to be moved to camera roll")
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: self.videoDataOutputFullFileName!))
                    }) { completed, error in
                        if completed {
                            print("Video \(self.videoDataOutputFullFileName) has been moved to camera roll")
                        }
                        
                        if error != nil {
                            print ("ERROR:::Cannot move the video \(self.videoDataOutputFullFileName) to camera roll, error: \(error!.localizedDescription)")
                        }
                    }
                } else {
                    print("ERROR:::The file: \(self.videoDataOutputFullFileName) not exists, so cannot move this file camera roll")
                }
            } else {
                print("WARN:::The videoWriter status is not completed, stauts: \(self.videoWriter!.status)")
            }
        }
        
    }
}



