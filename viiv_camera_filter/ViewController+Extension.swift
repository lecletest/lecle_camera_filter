//
//  ViewController+Extension.swift
//  viiv_camera_filter
//
//  Created by QuocHuynh on 10/20/21.
//

import UIKit
import AVFoundation
import MetalKit

extension ViewController {
    //MARK:- View Setup
    func setupView(){
        view.backgroundColor = .black
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mtkView)
        view.addSubview(switchCameraButton)
        view.addSubview(captureImageButton)
        view.addSubview(flashCameraButton)
        view.addSubview(recordCameraButton)
        view.addSubview(recordingLabel)
        
        recordingLabel.text = "Record Camera status"
        NSLayoutConstraint.activate([
            
            recordingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            recordingLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            
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
            
            
            recordCameraButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor,constant: 10),
            recordCameraButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            recordCameraButton.widthAnchor.constraint(equalToConstant: 50),
            recordCameraButton.heightAnchor.constraint(equalToConstant: 50),
            
            mtkView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mtkView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mtkView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mtkView.topAnchor.constraint(equalTo: view.topAnchor)
        ])
        
        switchCameraButton.addTarget(self, action: #selector(switchCamera(_:)), for: .touchUpInside)
        captureImageButton.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        flashCameraButton.addTarget(self, action: #selector(flashCamera(_:)), for: .touchUpInside)
        recordCameraButton.addTarget(self, action: #selector(recordCamera(_:)), for: .touchUpInside)
        
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
        let heightOfciImage = ciImage.extent.height
        let heightOfDrawable = view.drawableSize.height
        let yOffsetFromBottom = (heightOfDrawable - heightOfciImage)/2
        
        //        print(":::::::::::::::::::::::::START::::::::::::::::::::::::::::::")
        
        guard var  r = mBound else{
            return
        }
        
        r.size = view.drawableSize
        
        
        var scaleX = r.size.width/ciImage.extent.size.width
        var scaleY = r.size.height/ciImage.extent.size.height
        if(scaleX<1.0){
            scaleX = 1.0;
        }
        if(scaleY>1.0){
            scaleY = 1.0;
        }
        //        print("scaleX: \(scaleX)");
        //        print("scaleY: \(scaleY)");
        //        print("ciImage.extent.size.width: \(ciImage.extent.size.width)");
        //        print("ciImage.extent.size.height: \(ciImage.extent.size.height)");
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        ciImage = ciImage.transformed(by: transform)
        ciImage = ciImage.cropped(to: r)
        //        print("ciImage.extent.size.width after scale: \(ciImage.extent.size.width)");
        //        print("ciImage.extent.size.height after scale: \(ciImage.extent.size.height)");
        
        let x = r.origin.x
        let y = r.origin.y
        
        //        print("x: \(x)");
        //        print("y: \(y)");
        //        print("r.size: \(r.size.width)x\(r.size.height)");
        //
        //        print("::::::::::::::::::::::::::END:::::::::::::::::::::::::::::")
        // render into the metal texture
        self.ciContext.render(ciImage,
                              to: currentDrawable.texture,
                              commandBuffer: commandBuffer,
                              bounds: CGRect(origin: CGPoint(x: x, y: -yOffsetFromBottom), size: r.size),
                              //                              bounds: CGRect(origin: CGPoint(x: 0, y: yOffsetFromBottom), size: r.size),
                              colorSpace: CGColorSpaceCreateDeviceRGB())
        
        //register where to draw the instructions in the command buffer once it executes
        commandBuffer.present(currentDrawable)
        //commit the command to the queue so it executes
        commandBuffer.commit()
    }
}


extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // store sample time
        self.lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        
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
        
        let uiImage = UIImage(ciImage: filteredCIImage)
        
        self.currentCIImage = filteredCIImage
        
        // redraw MetalView
        mtkView.draw()
        
        if self.recording {
            if(output == videoDataOutput){
                
                //            if self.videoWriterInputPixelBufferAdaptor!.assetWriterInput.isReadyForMoreMediaData {
                //                if(filteredCIImage.pixelBuffer != nil){
                //                    let whetherPixelBufferAppendedtoAdaptor = self.videoWriterInputPixelBufferAdaptor?.append(filteredCIImage.pixelBuffer!, withPresentationTime: self.lastSampleTime)
                //
                //                    if whetherPixelBufferAppendedtoAdaptor != nil && whetherPixelBufferAppendedtoAdaptor! {
                //                        print("DEBUG:::PixelBuffer appended adaptor successfully")
                //                    } else {
                //                        print("WARN:::PixelBuffer appended adapotr failed")
                //                    }
                //                }
                //
                //            } else {
                //                print("WARN:::The assetWriterInput is not ready")
                //            }
                
                
                
                if self.videoWriterInputPixelBufferAdaptor!.assetWriterInput.isReadyForMoreMediaData {
                    
                    let filteredBuffer : CVPixelBuffer? = self.buffer(from: filteredCIImage)
                    self.filterContext.render(_:filteredCIImage, to:filteredBuffer!,bounds: filteredCIImage.extent,colorSpace: CGColorSpaceCreateDeviceRGB())
                    let whetherPixelBufferAppendedtoAdaptor = self.videoWriterInputPixelBufferAdaptor?.append(filteredBuffer!, withPresentationTime: self.lastSampleTime)
                    
                    if whetherPixelBufferAppendedtoAdaptor != nil && whetherPixelBufferAppendedtoAdaptor! {
                        print("DEBUG:::PixelBuffer Video appended adaptor successfully")
                    } else {
                        print("WARN:::PixelBuffer Video appended adapotr failed")
                    }
                    
                } else {
                    print("WARN:::The assetWriterInput is not ready")
                }
                
                
                //                if self.videoWriterInput!.isReadyForMoreMediaData {
                //                    if self.videoWriter!.status == AVAssetWriter.Status.writing {
                //
                //                        let whetherAppendSampleBuffer = self.videoWriterInput!.append(sampleBuffer)
                //
                //                        if whetherAppendSampleBuffer {
                //                            print("DEBUG::: Append Video sample buffer successfully")
                //                        } else {
                //                            print("WARN::: Append Video sample buffer failed")
                //                        }
                //                    } else {
                //                        print("WARN:::The Video videoWriter status is not writing")
                //                    }
                //
                //                } else {
                //                    print("WARN:::Cannot Video append sample buffer into videoWriterInput")
                //                }
            }else if (output  == audioDataOutput){
                if self.audioWriterInput!.isReadyForMoreMediaData {
                    if self.videoWriter!.status == AVAssetWriter.Status.writing {
                        let whetherAppendSampleBuffer = self.videoWriterInput!.append(sampleBuffer)
                        
                        if whetherAppendSampleBuffer {
                            print("DEBUG::: Append Audio sample buffer successfully")
                        } else {
                            print("WARN::: Append Audio sample buffer failed")
                        }
                    } else {
                        print("WARN:::The Audio videoWriter status is not writing")
                    }
                    
                } else {
                    print("WARN:::Cannot append Audio sample buffer into audioWriterInput")
                }
            }
            
        }
        
        
        
        if !takePicture {
            return //we have nothing to do with the image buffer
        }
        
        
        
        DispatchQueue.main.async {
            self.takePicture = false
            let path = self.saveImageToDocumentDirectory(uiImage)
            print("saveImageToDocumentDirectory: \(path)")
            
            if #available(iOS 9.0, *) {
                AudioServicesPlaySystemSoundWithCompletion(SystemSoundID(1108), nil)
            } else {
                AudioServicesPlaySystemSound(1108)
            }
            
        }
        
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("viiv")
        
    }
    
    func saveImageToDocumentDirectory(_ chosenImage: UIImage) -> String {
        let directoryPath =  self.getDocumentsDirectory().path
        if !FileManager.default.fileExists(atPath: directoryPath) {
            do {
                try FileManager.default.createDirectory(at: NSURL.fileURL(withPath: directoryPath), withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error)
            }
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddhhmmss"
        
        let filename = dateFormatter.string(from: Date()).appending(".jpg")
        let filepath = directoryPath.appending("/\(filename)")
        let url = NSURL.fileURL(withPath: filepath)
        
        do {
            try chosenImage.jpegData(compressionQuality: 1.0)?.write(to: url, options: .atomic)
            return filepath
            
        } catch {
            print(error)
            print("file cant not be save at path \(filepath), with error : \(error)");
            return filepath
        }
    }
    func buffer(from image: CIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        return pixelBuffer
    }
    
    
}

