//
//  ViewController+PickerView.swift
//  viiv_camera_filter
//
//  Created by QuocHuynh on 10/22/21.
//

import Foundation
import UIKit

extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource{
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int{
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int{
        
        return self.supportedFilters.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "Filter số \(row)"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        print("didSelectRow: \(self.supportedFilters[row])")
        self.currentFilter = CIFilter(name: "CIPhotoEffectFade")
        let filter = CIFilter(name: self.supportedFilters[row])
        let hasImageFilter = filter?.inputKeys.contains(kCIInputImageKey)
        if(hasImageFilter != nil){
            if(hasImageFilter!){
                self.currentFilter = filter
            }
        }
    }
    
    
}
