//
//  ViewController+Metal.swift
//  viiv_camera_filter
//
//  Created by QuocHuynh on 10/22/21.
//

import UIKit
import AVFoundation
import MetalKit

// ViewController Extension for Metal Kit
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

//        print(":::::::::::::::::::::::::START::::::::::::::::::::::::::::::")
    
        var r: CGRect = CGRect(x: 0, y: 0, width: view.drawableSize.width, height:  view.drawableSize.height)
        
        mVideoBound = r
        
        let scaleX = r.size.width/ciImage.extent.size.width
        let scaleY = r.size.height/ciImage.extent.size.height
        let scale = max(scaleX, scaleY)

        let transform = CGAffineTransform(scaleX: scale, y: scale)
        ciImage = ciImage.transformed(by: transform)
//        print("CIImage scaled \(ciImage.extent)")

        //make sure frame is centered on screen
        let heightOfciImage = ciImage.extent.height
        let heightOfDrawable = view.drawableSize.height
        let yOffsetFromBottom = (heightOfDrawable - heightOfciImage)/2

        
        /// coordinate of CIImage different graphic coordinate
        /// CIImage coordinate start from bottom left
        /// so we nee to translate it to center
        r.origin.y = -yOffsetFromBottom
//        print("::::::::::::::::::::::::::END:::::::::::::::::::::::::::::")
    
        
        // render into the metal texture
        self.ciContext.render(ciImage,
                              to: currentDrawable.texture,
                              commandBuffer: commandBuffer,
                              bounds: r,
                              colorSpace: CGColorSpaceCreateDeviceRGB())
        
        //register where to draw the instructions in the command buffer once it executes
        commandBuffer.present(currentDrawable)
        //commit the command to the queue so it executes
        commandBuffer.commit()
    }
}
