//
//  ViewController+Extension.swift
//  viiv_camera_filter
//
//  Created by QuocHuynh on 10/20/21.
//

import UIKit
import AVFoundation
import MetalKit

// ViewController Extension for setup View
extension ViewController {
    //MARK:- View Setup
    func setupView(){
        view.backgroundColor = .orange
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mtkView)
        view.addSubview(switchCameraButton)
        view.addSubview(captureImageButton)
        view.addSubview(flashCameraButton)
        view.addSubview(recordCameraButton)
        view.addSubview(recordingLabel)
        view.addSubview(filterCameraButton)
        
        filterPickerView.isHidden = true
        filterPickerView.delegate = self
        filterPickerView.dataSource = self
        view.addSubview(filterPickerView)
        
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
            
            filterCameraButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor,constant: -10),
            filterCameraButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            filterCameraButton.widthAnchor.constraint(equalToConstant: 50),
            filterCameraButton.heightAnchor.constraint(equalToConstant: 50),
            
            mtkView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,constant: -100),
            mtkView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor,constant: 0),
            mtkView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor,constant:0),
            mtkView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor,constant: 100),
       
        ])
        
        switchCameraButton.addTarget(self, action: #selector(switchCamera(_:)), for: .touchUpInside)
        captureImageButton.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        flashCameraButton.addTarget(self, action: #selector(flashCamera(_:)), for: .touchUpInside)
        recordCameraButton.addTarget(self, action: #selector(recordCamera(_:)), for: .touchUpInside)
        filterCameraButton.addTarget(self, action: #selector(filterCameraClicked(_:)), for: .touchUpInside)

        mVideoBound = mtkView.bounds
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



