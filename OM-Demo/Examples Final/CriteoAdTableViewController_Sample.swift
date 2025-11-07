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

    /// Track last applied visibility state per indexPath (true = playing)
    private var lastVisibilityState: [IndexPath: Bool] = [:]
    /// Throttle for scroll-driven updates
    private var lastVisibilityUpdateTimestamp: TimeInterval = 0
     /// Minimum interval between visibility recomputations during scrolling (seconds)
    private let visibilityUpdateThrottleInterval: TimeInterval = 0.12

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
        // Start playing only when the row center is visible (decided below)
            guard let self = self else { return }
            self.updateVideoVisibility(at: indexPath)
        }

        // No-op: pause/tap callbacks not needed for this sample but can be used as necessary for tracking purposes
        wrapper.onUserPauseStateChanged = nil
        wrapper.onVideoPaused = nil
        wrapper.onVideoStarted = nil
        wrapper.onVideoTapped = nil
        wrapper.onVideoError = nil
    }

    // MARK: - Video Management

    /// Center-based visibility rule for a single row.
    ///
    /// We treat the row's geometric center as the decision point: if the center
    /// lies inside the current viewport, we resume playback; if it leaves the
    /// viewport, we pause and detach. This avoids percentage thresholds, reduces
    /// jitter during scroll, and keeps one clear transition point.
    private func updateVideoVisibility(at indexPath: IndexPath) {
        guard let wrapper = videoAdWrappers[indexPath] else { return }

        // Viewport rect in tableView coordinates
        let viewport = CGRect(origin: tableView.contentOffset, size: tableView.bounds.size)
        // Row rect and its center point
        let rowRect = tableView.rectForRow(at: indexPath)
        let centerPoint = CGPoint(x: rowRect.midX, y: rowRect.midY)

        let centerIsVisible = viewport.contains(centerPoint)
        let currentlyPlaying = lastVisibilityState[indexPath] ?? false

        if centerIsVisible {
            if !currentlyPlaying {
                wrapper.resumePlayback()
                lastVisibilityState[indexPath] = true
            }
        } else {
            if currentlyPlaying {
                // Always detach when center is out of viewport (center-based)
                wrapper.pauseAndDetach()
                lastVisibilityState[indexPath] = false
            }
        }
    }

    /// Iterate visible rows and apply the center-based visibility rule.
    ///
    /// This is called on scroll (throttled) and when cells appear, delegating
    /// the actual decision to `updateVideoVisibility(at:)`.
    private func updateVisibleVideos() {
        guard let visibleIndexPaths = tableView.indexPathsForVisibleRows else { return }
        for indexPath in visibleIndexPaths {
            if case .videoAd = feedItems[indexPath.row] {
                updateVideoVisibility(at: indexPath)
            }
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
        // Apply center-based visibility rule when cell becomes visible
        if case .videoAd = feedItems[indexPath.row], videoAdWrappers[indexPath] != nil {
            updateVideoVisibility(at: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Handle video visibility when cell goes out of view
        if case .videoAd = feedItems[indexPath.row], videoAdWrappers[indexPath] != nil {
            videoAdWrappers[indexPath]?.pauseAndDetach()
            lastVisibilityState[indexPath] = false
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

    // Keep video state in sync while scrolling using center-based visibility rule
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Throttle updates to ~8 fps to avoid jitter while scrolling
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastVisibilityUpdateTimestamp > visibilityUpdateThrottleInterval {
            lastVisibilityUpdateTimestamp = now
            updateVisibleVideos()
        }
    }
}

// MARK: - Supporting Types

/// Represents different types of items in the feed
enum FeedItem {
    case content(title: String, description: String)
    case videoAd(vastURL: String)
}
