//
//  CriteoAdTableViewController_Sample.swift
//  OM-Demo
//
//  Created by Serxhio Gugo on 8/26/25.
//  Copyright © 2025 Open Measurement Working Group. All rights reserved.
//

import UIKit

#if canImport(OMSDK_Criteo)
import OMSDK_Criteo
#endif

/// Table view controller demonstrating video ads in a feed using CriteoVideoAdWrapper
class CriteoAdTableViewController_Sample: UITableViewController {

    // MARK: - Properties

    /// Sample data for the feed (20 items with video ad at index 15)
    private var feedItems: [FeedItem] = []

    /// Video ad wrappers for each video ad (using identifier for state persistence)
    private var videoAdWrappers: [IndexPath: CriteoVideoAdWrapper] = [:]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        generateFeedData()
        startVideoAdPreloading() // Start preloading video ad immediately
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause any currently playing video when leaving
        pauseAllVideos()
    }

    deinit {
        // Clean up all video wrappers
        videoAdWrappers.removeAll()
    }

    // MARK: - Setup

    // Example UI + data source setup code
    private func setupTableView() {
        title = "Video Feed Sample"
        
        tableView.register(CriteoAdCell_Sample.self, forCellReuseIdentifier: "VideoAdCell")
        tableView.register(ContentTableViewCell.self, forCellReuseIdentifier: "ContentCell")
        
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor.systemGroupedBackground
        tableView.estimatedRowHeight = 300
        tableView.rowHeight = UITableView.automaticDimension
    }

    private func generateFeedData() {
        // Create 20 feed items with video ad at index 15
        feedItems = []
        for i in 1...15 {
            feedItems.append(.content(
                title: "Content Item \(i)",
                description: "This is sample content for item \(i). It demonstrates how regular content appears in the feed alongside video ads."
            ))
        }
        feedItems.append(.videoAd(vastURL: Constants.vastURL))
        
        for i in 16...19 {
            feedItems.append(.content(
                title: "Content Item \(i)",
                description: "This is sample content for item \(i). It demonstrates how regular content appears in the feed alongside video ads."
            ))
        }

        tableView.reloadData()
    }

    /// Scans the feed data to find all video ads and initiates their preloading process.
    private func startVideoAdPreloading() {
        // Find video ad and start preloading immediately
        for (index, item) in feedItems.enumerated() {
            if case .videoAd(let vastURL) = item {
                let indexPath = IndexPath(row: index, section: 0)
                preloadVideoAd(at: indexPath, vastURL: vastURL)
                break
            }
        }
    }

    /// Creates and configures a CriteoVideoAdWrapper for a specific video ad position.
    private func preloadVideoAd(at indexPath: IndexPath, vastURL: String) {
        // Create wrapper without identifier to prevent state persistence across VC instances
        let wrapper = CriteoVideoAdWrapper(vastURL: vastURL, identifier: nil,
            configuration: .init(
                autoLoad: false,
                startsMuted: true, // Video starts muted
                backgroundColor: .white,
                cornerRadius: 8
            )
        )

        // Enable logging for this wrapper instance (same as single video controller)
        wrapper.enableLogs = [.vast, .network, .video, .beacon, .omid, .ui]

        // Set up callbacks
        setupWrapperCallbacks(wrapper, for: indexPath)

        // Start preloading
        wrapper.preloadAssets()

        // Store wrapper
        videoAdWrappers[indexPath] = wrapper

        CriteoLogger.info("🚀 Started preloading video ad at \(indexPath)", category: .video)
    }

    /// Configures all event callback handlers for a CriteoVideoAdWrapper instance.
    private func setupWrapperCallbacks(_ wrapper: CriteoVideoAdWrapper, for indexPath: IndexPath) {
        // Video loaded callback
        wrapper.onVideoLoaded = { [weak self] in
            // Only start playing if the cell is actually visible
            if let self = self,
               let visibleIndexPaths = self.tableView.indexPathsForVisibleRows,
               visibleIndexPaths.contains(indexPath) {
                self.handleVideoVisibility(at: indexPath, isVisible: true)
            }
        }

        // No-op: pause/tap callbacks not needed for this sample but can be used as necessary for tracking purposes
        wrapper.onUserPauseStateChanged = nil
        wrapper.onVideoPaused = nil
        wrapper.onVideoStarted = nil
        wrapper.onVideoTapped = nil
        wrapper.onVideoError = nil
    }

    // MARK: - Video Management

    /// Handles play/pause logic based on video cell visibility in the table view.
    private func handleVideoVisibility(at indexPath: IndexPath, isVisible: Bool) {
        guard let wrapper = videoAdWrappers[indexPath] else {
            CriteoLogger.warning("⚠️ No wrapper found for \(indexPath)", category: .video)
            return
        }
        if isVisible {
            wrapper.resumePlayback()
        } else {
            wrapper.pauseAndDetach()
        }
    }

    /// Pauses and detaches all currently active video ads in the feed.
    private func pauseAllVideos() {
        for (_, wrapper) in videoAdWrappers {
            // Pause and detach - wrapper handles position saving internally
            wrapper.pauseAndDetach()
        }
    }
}

// MARK: - UITableViewDataSource

extension CriteoAdTableViewController_Sample {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feedItems.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = feedItems[indexPath.row]

        switch item {
        case .content(let title, let description):
            let cell = tableView.dequeueReusableCell(withIdentifier: "ContentCell", for: indexPath) as! ContentTableViewCell
            cell.configure(title: title, description: description)
            return cell

        case .videoAd:
            let cell = tableView.dequeueReusableCell(withIdentifier: "VideoAdCell", for: indexPath) as! CriteoAdCell_Sample
            cell.configure(with: videoAdWrappers[indexPath])
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension CriteoAdTableViewController_Sample {

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Handle video visibility when cell becomes visible
        if case .videoAd = feedItems[indexPath.row], videoAdWrappers[indexPath] != nil {
            handleVideoVisibility(at: indexPath, isVisible: true)
        }
    }

    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Handle video visibility when cell goes out of view
        if case .videoAd = feedItems[indexPath.row], videoAdWrappers[indexPath] != nil {
            handleVideoVisibility(at: indexPath, isVisible: false)
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch feedItems[indexPath.row] {
        case .content:
            return UITableView.automaticDimension
        case .videoAd:
            // 16:9 aspect ratio for video
            return tableView.bounds.width * 9.0 / 16.0 + 120 // Add space for header/footer
        }
    }
}

// MARK: - Supporting Types

/// Represents different types of items in the feed
enum FeedItem {
    case content(title: String, description: String)
    case videoAd(vastURL: String)
}
