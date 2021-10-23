//
//  ViewController+Capture.swift
//  viiv_camera_filter
//
//  Created by QuocHuynh on 10/22/21.
//

import Foundation
import AVFoundation
import UIKit


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
       
        self.currentCIImage = filteredCIImage
    
    
        // redraw MetalView
        mtkView.draw()
        
        
        if self.recording {
            if(output == videoDataOutput){
                if self.videoWriterInputPixelBufferAdaptor!.assetWriterInput.isReadyForMoreMediaData {
                    
                    let filteredBuffer : CVPixelBuffer? = self.buffer(from: filteredCIImage)
                    
                    self.filterContext.render(_:filteredCIImage, to:filteredBuffer!)
                    
                    let whetherPixelBufferAppendedtoAdaptor = self.videoWriterInputPixelBufferAdaptor?.append(filteredBuffer!, withPresentationTime: self.lastSampleTime)
                    
                    if whetherPixelBufferAppendedtoAdaptor != nil && whetherPixelBufferAppendedtoAdaptor! {
                        print("DEBUG:::PixelBuffer Video appended adaptor successfully")
                    } else {
                        print("WARN:::PixelBuffer Video appended adapotr failed")
                    }
                    
                } else {
                    print("WARN:::The assetWriterInput is not ready")
                }
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
            return
        }
        
        DispatchQueue.main.async {
            self.takePicture = false
            let uiImage = UIImage(ciImage: filteredCIImage)
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
    
    //
    // Convert CIImage to sample buffer to re render filtered image
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

