//
//  SingleVideoController.swift
//  OM-Demo
//
//  Created by Serxhio Gugo on 8/26/25.
//  Copyright © 2025 Open Measurement Working Group. All rights reserved.
//

import UIKit

class CriteoAdSingleVideoController_Sample: UIViewController {
    
    // Keep a reference to the video ad for cleanup
    private var videoAd: CriteoVideoAdWrapper?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupCriteoVideoAd()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cleanupVideoAd()
    }
    
    deinit {
        cleanupVideoAd()
    }
    
    private func setupCriteoVideoAd() {
        // Create the video ad wrapper with the working VAST URL from the demo
        let config = CriteoVideoAdConfiguration(autoLoad: true, startsMuted: false)
        let videoAd = CriteoVideoAdWrapper(vastURL: Constants.vastURL, configuration: config)
        self.videoAd = videoAd  // Store reference for cleanup
        
        // Enable specific logging categories
        videoAd.enableLogs = [.network, .beacon, .video]
        
        videoAd.onVideoLoaded = { [weak self] in
            // Start playback immediately when video loads
            self?.videoAd?.resumePlayback()
        }
        
        // Add to view (UI Constraints)
        view.addSubview(videoAd)
        
        videoAd.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            videoAd.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            videoAd.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            videoAd.widthAnchor.constraint(equalToConstant: 350),
            videoAd.heightAnchor.constraint(equalToConstant: 197)
        ])
    }
    
    private func cleanupVideoAd() {
        if let videoAd = videoAd {
            // Stop playback and clean up resources
            videoAd.pauseAndDetach()
            
            // Remove from view hierarchy
            videoAd.removeFromSuperview()
            
            // Clear callbacks to prevent retain cycles
            videoAd.onVideoLoaded = nil
            videoAd.onVideoError = nil
            videoAd.onVideoStarted = nil
            videoAd.onVideoPaused = nil
            videoAd.onUserPauseStateChanged = nil
            videoAd.onPlaybackProgress = nil
            videoAd.onVideoTapped = nil
        }
        
        videoAd = nil
    }
}
