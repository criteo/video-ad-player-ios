//
//  CriteoVideoAdWrapper.swift
//  OM-Demo
//
//  Created by Serxhio Gugo on 8/23/25.
//  Copyright © 2025 Open Measurement Working Group. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMedia

/**
 * CriteoVideoAdWrapper - The FINAL client-facing wrapper for video ad integration
 *
 * This is the complete, production-ready wrapper that abstracts away all complexity:
 * - VAST XML parsing and validation
 * - Asset downloading and caching
 * - OMID measurement integration
 * - Beacon tracking
 * - Video player lifecycle management
 * - State persistence and resume functionality
 * - Error handling and retry logic
 *
 * USAGE EXAMPLES:
 *
 * 1. Simple Single Video:
 * ```swift
 * let videoAd = CriteoVideoAdWrapper(vastURL: "https://example.com/vast.xml")
 * videoAd.onVideoLoaded = { print("Ready to play!") }
 * videoAd.onVideoError = { error in print("Error: \(error)") }
 * view.addSubview(videoAd)
 * ```
 *
 * 2. Feed Integration with Position Persistence:
 * ```swift
 * let videoAd = CriteoVideoAdWrapper(vastURL: "https://example.com/vast.xml", identifier: "feed-item-123")
 * videoAd.preloadAssets() // Download in background
 * // Later when visible:
 * videoAd.resumePlayback() // Continues from where user left off
 * ```
 */
public class CriteoVideoAdWrapper: UIView {
    
    // MARK: - Public API
    
    /// Unique identifier for state persistence (optional)
    public let identifier: String?
    
    /// VAST source (URL or raw XML). Backwards compatible via legacy init.
    public enum VASTSource {
        case url(String)
        case xml(String)
    }

    /// VAST source provided at initialization
    public let vastSource: VASTSource
    
    /// Configuration options
    public var configuration: CriteoVideoAdConfiguration
    
    /// Enable specific log categories for this wrapper instance
    /// Setting this will control ALL logging globally (wrapper, player, managers, etc.)
    public var enableLogs: Set<CriteoVideoAdLogCategory> = [] {
        didSet {
            updateGlobalLogging()
        }
    }
    
    // MARK: - Event Callbacks
    
    /// Called when video assets are downloaded and ready to play
    public var onVideoLoaded: (() -> Void)?
    
    /// Called when video playback starts
    public var onVideoStarted: (() -> Void)?
    
    /// Called when video playback is paused (user or programmatic)
    public var onVideoPaused: (() -> Void)?
    
    /// Called when user taps on the video
    public var onVideoTapped: (() -> Void)?
    
    /// Called when an error occurs
    public var onVideoError: ((Error) -> Void)?
    
    /// Called with playback progress updates
    public var onPlaybackProgress: ((TimeInterval, TimeInterval) -> Void)?
    
    /// Called when user pause state changes (important for preserving manual pause across visibility changes)
    public var onUserPauseStateChanged: ((Bool) -> Void)?
    
    // MARK: - Public State Properties
    
    /// Whether Closed Captions are currently enabled
    public var isClosedCaptionEnabled: Bool {
        return videoPlayer?.isClosedCaptionEnabled ?? true
    }
    
    /// Whether the video is currently playing
    public var isPlaying: Bool {
        return videoPlayer?.playbackState == .playing
    }
    
    private var savedMutedState: Bool = false // Track mute state across player recreation
    
    /// Whether the video is muted
    public var isMuted: Bool {
        return videoPlayer?.isMuted ?? false
    }
    
    /// Current playback time in seconds
    public var currentTime: TimeInterval {
        return videoPlayer?.getCurrentTime() ?? 0.0
    }
    
    /// Video duration in seconds
    public var duration: TimeInterval {
        return videoPlayer?.duration ?? 0.0
    }
    
    /// Current loading/playback state
    public var state: CriteoVideoAdState {
        return currentState
    }
    
    // MARK: - Private Properties
    
    private var currentState: CriteoVideoAdState = .notLoaded {
        didSet {
            updateUIForState()
        }
    }
    
    // MARK: - Private Properties
    private var savedClosedCaptionsEnabled: Bool = true // Track CC state across player recreation
    private var videoPlayer: CriteoVideoPlayer?
    private var vastAd: VASTAd?
    private var videoAssetURL: URL?
    private var closedCaptionsAssetURL: URL?
    private var lastPlaybackPosition: TimeInterval = 0.0
    private var isUserPaused: Bool = false
    private var preloadTask: Task<Void, Never>?
    
    // Manager instances (abstracted from client)
    private let networkManager = NetworkManager.shared
    private let creativeDownloader = CreativeDownloaderAsync()
    
    // UI Components
    private let loadingContainerView = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()
    private let errorContainerView = UIView()
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    
    // MARK: - Initialization
    
    /**
     * Initialize with VAST URL
     * - Parameter vastURL: URL string pointing to VAST XML
     * - Parameter identifier: Optional unique identifier for state persistence
     * - Parameter configuration: Configuration options
     */
    public init(vastURL: String, identifier: String? = nil, configuration: CriteoVideoAdConfiguration = .default) {
        self.vastSource = .url(vastURL)
        self.identifier = identifier
        self.configuration = configuration

        // Initialize mute state based on configuration
        self.savedMutedState = configuration.startsMuted

        super.init(frame: .zero)

        setupUI()

        if configuration.autoLoad {
            loadVideoAd()
        }
    }

    /// New initializer supporting either URL or raw XML
    public init(source: VASTSource, identifier: String? = nil, configuration: CriteoVideoAdConfiguration = .default) {
        self.vastSource = source
        self.identifier = identifier
        self.configuration = configuration

        // Initialize mute state based on configuration
        self.savedMutedState = configuration.startsMuted

        super.init(frame: .zero)

        setupUI()

        if configuration.autoLoad {
            loadVideoAd()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented - use init(vastURL:identifier:configuration:) instead")
    }
    
    deinit {
        preloadTask?.cancel()
        videoPlayer?.stopOMIDSession()
        videoPlayer?.cleanup()
        
        // Save state if identifier provided
        if let identifier = identifier {
            saveState(for: identifier)
        }
    }
    
    // MARK: - Static Methods
    
    /**
     * Control global logging for all video ad components
     * Use this when you want to control logging without creating a wrapper instance
     */
    public static func setGlobalLogging(_ categories: Set<CriteoVideoAdLogCategory>) {
        let loggerCategories = categories.map { $0.loggerCategory }
        if loggerCategories.isEmpty {
            CriteoLogger.disable(CriteoLogger.Category.allCases)
        } else {
            CriteoLogger.enableOnly(loggerCategories)
        }
    }
    
    /**
     * Disable all video ad logging globally
     */
    public static func disableAllLogging() {
            CriteoLogger.disable(CriteoLogger.Category.allCases)
    }
    
    // MARK: - Public Methods
    
    /**
     * Manually load the video ad (if autoLoad is disabled)
     */
    public func loadVideoAd() {
        guard currentState == .notLoaded else { return }

        currentState = .loading

        preloadTask = Task {
            await performAssetDownload()
        }
    }

    /**
     * Preload assets in background without showing UI
     */
    public func preloadAssets() {
        guard currentState == .notLoaded else { return }

        preloadTask = Task {
            await performAssetDownload()
        }
    }
        
    /**
     * Start or resume video playback
     */
    public func play() {
        guard let player = videoPlayer else { return }
        
        isUserPaused = false
        player.play()
        // Note: onVideoStarted?() will be called by delegate when playback actually starts
    }
    
    /**
     * Pause video playback
     */
    public func pause() {
        guard let player = videoPlayer else { return }
        
        isUserPaused = true
        lastPlaybackPosition = player.getCurrentTime()
        player.pause()
        // Note: onVideoPaused?() will be called by delegate when playback actually pauses
    }
    
    /**
     * Resume playback from last position (for feed scenarios)
     */
    public func resumePlayback() {
        guard case .ready = currentState else {
            wrapperLog("resumePlayback called but state is not ready: \(currentState)", category: .video)
            return
        }
        
        if let player = videoPlayer {
            wrapperLog("Resuming existing video player", category: .video)
            // Player already exists, just resume
            if !isUserPaused && lastPlaybackPosition > 0 {
                // Use precise seeking for consistent timing accuracy across all scenarios
                player.seekPreciselyTo(time: lastPlaybackPosition) { [weak self] finished in
                    if finished {
                        self?.wrapperLog("Precise seek completed for existing player at \(self?.lastPlaybackPosition ?? 0)s", category: .video)
                    } else {
                        self?.wrapperLog("Precise seek failed for existing player", category: .video)
                    }
                }
                self.wrapperLog("Precise seek initiated for existing player to \(lastPlaybackPosition)s", category: .video)
            } else if !isUserPaused {
                player.play()

                // Smooth fade-in transition when video starts playing
                UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseOut) {
                    player.alpha = 1.0
                }
            } else {
                // If user paused, still make sure player is visible but don't play
                UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseOut) {
                    player.alpha = 1.0
                }
            }
        } else {
            wrapperLog("No video player exists, creating new one", category: .video)
            // Create player and set it up
            setupVideoPlayer()
        }
    }
    
    /**
     * Pause and detach from view (for feed scenarios)
     */
    public func pauseAndDetach() {
        guard let player = videoPlayer else {
            wrapperLog("pauseAndDetach called but no video player exists", category: .video)
            return
        }
        
        // Smooth fade-out before pausing
        UIView.animate(withDuration: 0.2, animations: {
            player.alpha = 0.0
        }) { _ in
            player.pause()
            player.removeFromSuperview()
        }
        
        // Save CC and mute states before clearing player reference
        savedClosedCaptionsEnabled = player.isClosedCaptionEnabled
        savedMutedState = player.isMuted
        wrapperLog("Saved mute state on detach: \(savedMutedState)", category: .video)
        
        // Save position after a brief delay for accuracy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self = self else { return }
            self.lastPlaybackPosition = player.getCurrentTime()
            self.wrapperLog("Saved position on detach: \(self.lastPlaybackPosition)s", category: .video)
        }
        
        // Clear the video player reference so resumePlayback() will create a fresh one
        videoPlayer = nil
        
        wrapperLog("Video player detached and cleared, will create fresh player on resume", category: .video)
    }
    
    /**
     * Seek to specific time in seconds
     */
    public func seekTo(time: TimeInterval) {
        videoPlayer?.seekTo(time: time)
        lastPlaybackPosition = time
    }
    
    /**
     * Toggle mute state
     */
    public func toggleMute() {
        videoPlayer?.toggleMute()
    }
    
    /**
     * Retry loading after an error
     */
    public func retry() {
        currentState = .notLoaded
        loadVideoAd()
    }
    
    // MARK: - Private Implementation
    
    private func setupUI() {
        backgroundColor = configuration.backgroundColor
        layer.cornerRadius = configuration.cornerRadius
        clipsToBounds = true
        
        setupLoadingUI()
        setupErrorUI()
        
        // Always start with notLoaded - the init() will call loadVideoAd() if autoLoad is enabled
        currentState = .notLoaded
    }
    
    private func setupLoadingUI() {
        loadingContainerView.backgroundColor = configuration.loadingBackgroundColor
        loadingContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        loadingIndicator.color = configuration.loadingIndicatorColor
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        loadingLabel.text = configuration.loadingText
        loadingLabel.textColor = configuration.loadingTextColor
        loadingLabel.font = configuration.loadingFont
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(loadingContainerView)
        loadingContainerView.addSubview(loadingIndicator)
        loadingContainerView.addSubview(loadingLabel)
        
        NSLayoutConstraint.activate([
            loadingContainerView.topAnchor.constraint(equalTo: topAnchor),
            loadingContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            loadingContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            loadingContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingContainerView.centerYAnchor, constant: -10),
            
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 12),
            loadingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: loadingContainerView.leadingAnchor, constant: 16),
            loadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: loadingContainerView.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupErrorUI() {
        errorContainerView.backgroundColor = configuration.errorBackgroundColor
        errorContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        errorLabel.textColor = configuration.errorTextColor
        errorLabel.font = configuration.errorFont
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        retryButton.setTitle(configuration.retryButtonText, for: .normal)
        retryButton.setTitleColor(configuration.retryButtonColor, for: .normal)
        retryButton.titleLabel?.font = configuration.retryButtonFont
        retryButton.backgroundColor = configuration.retryButtonBackgroundColor
        retryButton.layer.cornerRadius = 8
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        
        addSubview(errorContainerView)
        errorContainerView.addSubview(errorLabel)
        errorContainerView.addSubview(retryButton)
        
        NSLayoutConstraint.activate([
            errorContainerView.topAnchor.constraint(equalTo: topAnchor),
            errorContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            errorContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            errorContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            errorLabel.centerXAnchor.constraint(equalTo: errorContainerView.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: errorContainerView.centerYAnchor, constant: -20),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: errorContainerView.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: errorContainerView.trailingAnchor, constant: -16),
            
            retryButton.centerXAnchor.constraint(equalTo: errorContainerView.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 16),
            retryButton.widthAnchor.constraint(equalToConstant: 120),
            retryButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func updateUIForState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch self.currentState {
            case .notLoaded:
                self.loadingContainerView.isHidden = true
                self.errorContainerView.isHidden = true
                self.loadingIndicator.stopAnimating()
                
            case .loading:
                self.wrapperLog("Showing loading indicator with fade-in", category: .ui)
                self.loadingContainerView.alpha = 0.0
                self.loadingContainerView.isHidden = false
                self.errorContainerView.isHidden = true
                self.loadingIndicator.startAnimating()
                
                // Smooth fade-in for loading indicator
                UIView.animate(withDuration: 0.2) {
                    self.loadingContainerView.alpha = 1.0
                }
                
            case .ready:
                self.wrapperLog("Hiding loading indicator with fade-out", category: .ui)
                // Smooth transition from loading to video
                UIView.animate(withDuration: 0.3, animations: {
                    self.loadingContainerView.alpha = 0.0
                }) { _ in
                    self.loadingContainerView.isHidden = true
                    self.loadingContainerView.alpha = 1.0 // Reset for next time
                    self.loadingIndicator.stopAnimating()
                }
                self.errorContainerView.isHidden = true
                
            case .error(let error):
                self.loadingContainerView.isHidden = true
                self.errorContainerView.isHidden = false
                self.loadingIndicator.stopAnimating()
                self.errorLabel.text = error.localizedDescription
            }
        }
    }
    
    private func performAssetDownload() async {
        do {
            // Step 1: Parse VAST XML
            wrapperLog("Starting VAST parsing", category: .vast)
            let vastAd: VASTAd
            switch self.vastSource {
            case .url(let urlString):
                guard let url = URL(string: urlString) else {
                    throw CriteoVideoAdError.invalidURL(urlString)
                }
                vastAd = try await networkManager.fetchAndParseVAST(from: url)
            case .xml(let xmlString):
                vastAd = await networkManager.parseVAST(fromXML: xmlString)
            }
            wrapperLog("VAST parsed successfully", category: .vast)
            self.vastAd = vastAd
            
            // Step 2: Select and download video asset (supports multiple MediaFiles)
            let selectedURL = selectBestMediaURL(from: vastAd)
            guard let videoURL = selectedURL ?? vastAd.videoURL else {
                throw CriteoVideoAdError.noVideoURL
            }

            wrapperLog("Starting video download: \(videoURL)", category: .network)
            let localVideoURL = try await creativeDownloader.fetchCreative(from: videoURL)
            wrapperLog("Video downloaded successfully", category: .network)
            self.videoAssetURL = localVideoURL
            
            // Step 3: Download closed captions (if available)
            if let ccURL = selectCaptionURL(from: vastAd, for: videoURL) ?? vastAd.closedCaptionURL {
                wrapperLog("Starting closed captions download: \(ccURL)", category: .network)
                self.closedCaptionsAssetURL = try await creativeDownloader.fetchCreative(from: ccURL)
                wrapperLog("Closed Captions downloaded successfully", category: .network)
            }
            
            // Step 4: Update state and notify
            await MainActor.run {
                // Restore saved state if identifier provided
                if let identifier = self.identifier {
                    self.restoreState(for: identifier)
                }
                
                self.currentState = .ready
                self.onVideoLoaded?()
            }
            
        } catch {
            wrapperLog("Asset download failed: \(error)", category: .network)
            await MainActor.run {
                self.currentState = .error(error)
                self.onVideoError?(error)
            }
        }
    }
    
    private func setupVideoPlayer() {
        guard case .ready = currentState,
              let vastAd = vastAd,
              let videoAssetURL = videoAssetURL else { return }
        
        wrapperLog("Setting up video player", category: .video)
        
        // Remove existing player if any
        videoPlayer?.removeFromSuperview()
        videoPlayer?.cleanup()
        
        // Create new player
        let player = CriteoVideoPlayer()
        player.translatesAutoresizingMaskIntoConstraints = false
        
        // Pass logging settings to player
        player.enableInternalLogging = enableLogs
        
        // Configure player callbacks
        setupPlayerCallbacks(player)

        // Sync the player's initial CC state with the wrapper's saved state
        // Mute state will be set after video loading to avoid AVPlayer recreation issues
        player.isClosedCaptionEnabled = savedClosedCaptionsEnabled
        wrapperLog("Set player CC state to \(savedClosedCaptionsEnabled)", category: .video)

        // Add to view - start invisible for smooth fade-in transition
        player.alpha = 0.0  // Start invisible for smooth transition
        addSubview(player)
        NSLayoutConstraint.activate([
            player.topAnchor.constraint(equalTo: topAnchor),
            player.leadingAnchor.constraint(equalTo: leadingAnchor),
            player.trailingAnchor.constraint(equalTo: trailingAnchor),
            player.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Bring to front to ensure visibility
        bringSubviewToFront(player)
        
        // Load assets
        wrapperLog("Loading video content into player", category: .video)
        player.setVASTAd(vastAd)
        player.loadVideo(from: videoAssetURL)

        // Set mute state AFTER loading video (since loadVideo creates new AVPlayer)
        player.isMuted = savedMutedState

        if let closedCaptionsAssetURL = closedCaptionsAssetURL {
            wrapperLog("Loading closed captions into player", category: .video)
            player.loadClosedCaptions(from: closedCaptionsAssetURL)
        }
        
        // Setup OMID session
        if let vendorKey = vastAd.vendorKey,
           let verificationScriptURL = vastAd.verificationScriptURL?.absoluteString,
           let verificationParameters = vastAd.verificationParameters {
            player.setupOMIDSession(
                vendorKey: vendorKey,
                verificationScriptURL: verificationScriptURL,
                verificationParameters: verificationParameters
            )
        }
        
        // Fire impression events
        player.fireImpressionEvents()
        
        // Handle resume from saved position
        if lastPlaybackPosition > 0 {
            // Always seek to saved position if we have one, regardless of pause state
            // Use precise seeking for consistent timing accuracy across all scenarios
            player.seekPreciselyTo(time: lastPlaybackPosition) { [weak self] finished in
                if finished {
                    // Update duration label immediately after seeking to show correct time
                    if let self = self {
                        self.updateDurationLabelForPlayer(player)
                    }
                }
            }
            self.wrapperLog("Precise seek initiated to \(lastPlaybackPosition)s", category: .video)
        }
        
        // Always make the player visible with smooth fade-in
        UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseOut) {
            player.alpha = 1.0
        }

        // Only auto-play if not user-paused
        if !isUserPaused {
            player.play()
        }

        // Update duration label after player is fully set up
        if lastPlaybackPosition > 0 {
            // Try immediate update, player status observer will handle if not ready
            updateDurationLabelForPlayer(player)
        }

        // Store reference
        videoPlayer = player
    }

    // MARK: - Media Selection Helpers

    /// Select the best media file URL based on this view's current aspect ratio.
    private func selectBestMediaURL(from ad: VASTAd) -> URL? {
        guard !ad.mediaFiles.isEmpty else { return nil }

        // Use current bounds to determine target ratio; default to 16:9 when not laid out yet
        let targetRatio: CGFloat
        if bounds.height > 0 {
            targetRatio = bounds.width / max(bounds.height, 1)
        } else {
            targetRatio = 16.0 / 9.0
        }

        func ratio(of media: VASTMediaFile) -> CGFloat? {
            if let w = media.width, let h = media.height, h > 0 { return CGFloat(w) / CGFloat(h) }
            return nil
        }

        // Consider only MP4 media files; pick closest by aspect ratio
        let candidates = ad.mediaFiles.filter { ($0.type ?? "").contains("mp4") }
        guard !candidates.isEmpty else { return nil }

        let selected = candidates.min { a, b in
            let ra = ratio(of: a) ?? .greatestFiniteMagnitude
            let rb = ratio(of: b) ?? .greatestFiniteMagnitude
            return abs(ra - targetRatio) < abs(rb - targetRatio)
        }

        return selected?.url
    }

    /// Return the caption URL associated with the selected media, if any.
    private func selectCaptionURL(from ad: VASTAd, for mediaURL: URL) -> URL? {
        if let media = ad.mediaFiles.first(where: { $0.url == mediaURL }) {
            return media.captionURL
        }
        return nil
    }

    /// Update the duration label for a specific player instance
    private func updateDurationLabelForPlayer(_ player: CriteoVideoPlayer) {
        let currentTime = player.currentTime
        let duration = player.duration

        // Force update the duration label on the player
        if duration > 0 {
            player.updateDurationLabelImmediately(currentTime: currentTime, duration: duration)
        } else {
            // Duration not available yet - try again in 0.1s
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateDurationLabelForPlayerWhenReady(player, expectedCurrentTime: currentTime)
            }
        }
    }

    /// Update duration label when duration becomes available
    private func updateDurationLabelForPlayerWhenReady(_ player: CriteoVideoPlayer, expectedCurrentTime: TimeInterval) {
        let currentTime = player.currentTime
        let duration = player.duration

        if duration > 0 {
            player.updateDurationLabelImmediately(currentTime: currentTime, duration: duration)
        }
    }
    
    private func setupPlayerCallbacks(_ player: CriteoVideoPlayer) {
        // Set delegate for all player events
        player.delegate = self

        // Observe player status to update duration label when ready
        player.observePlayerStatus { [weak self] status in
            if status == .readyToPlay, let self = self, self.lastPlaybackPosition > 0 {
                // Player is ready - update duration label immediately
                self.updateDurationLabelForPlayer(player)
            }
        }

        // Set up user pause state callback to sync with wrapper's state
        player.onUserPauseStateChanged = { [weak self] isUserPaused in
            self?.isUserPaused = isUserPaused
            // Notify external listeners about the pause state change
            self?.onUserPauseStateChanged?(isUserPaused)
        }
        
        // Sync the player's initial pause state with the wrapper's state
        player.setUserPauseState(isUserPaused)
        
        // If we have a saved playback position, pass it to the player
        if lastPlaybackPosition > 0 {
            player.setInitialPlaybackPosition(lastPlaybackPosition)
            wrapperLog("Set player initial position to \(lastPlaybackPosition)s", category: .video)
        }
    }
    
    // MARK: - State Persistence
    
    private func saveState(for identifier: String) {
        let state = CriteoVideoAdPersistedState(
            lastPlaybackPosition: lastPlaybackPosition,
            isUserPaused: isUserPaused,
            isClosedCaptionsEnabled: savedClosedCaptionsEnabled,
            isMuted: savedMutedState
        )
        
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "CriteoVideoAd_\(identifier)")
        }
    }
    
    private func restoreState(for identifier: String) {
        guard let data = UserDefaults.standard.data(forKey: "CriteoVideoAd_\(identifier)"),
              let state = try? JSONDecoder().decode(CriteoVideoAdPersistedState.self, from: data) else {
            return
        }
        
        lastPlaybackPosition = state.lastPlaybackPosition
        isUserPaused = state.isUserPaused
        savedClosedCaptionsEnabled = state.closedCaptionsEnabled
        savedMutedState = state.muted
    }
    
    // MARK: - Actions
    
    @objc private func retryButtonTapped() {
        wrapperLog("Retry button tapped", category: .ui)
        retry()
    }
    
    // MARK: - Logging Helper
    
    private func wrapperLog(_ message: String, category: CriteoVideoAdLogCategory) {
        guard enableLogs.contains(category) else { return }
        CriteoLogger.info("[Wrapper] \(message)", category: category.loggerCategory)
    }
    
    private func updateGlobalLogging() {
        let loggerCategories = enableLogs.map { $0.loggerCategory }
        if loggerCategories.isEmpty {
            // Disable all logging by enabling a non-existent category
            // This effectively disables all categories since none will match
            CriteoLogger.disable(CriteoLogger.Category.allCases)
        } else {
            // Enable only specified categories globally
            CriteoLogger.enableOnly(loggerCategories)
        }
        
        // Also update player's internal logging (for consistency)
        videoPlayer?.enableInternalLogging = enableLogs
    }
}

// MARK: - CriteoVideoPlayerDelegate

extension CriteoVideoAdWrapper: CriteoVideoPlayerDelegate {
    
    func videoPlayer(_ player: CriteoVideoPlayer, didReachQuartile quartile: VideoQuartile) {
        wrapperLog("Video quartile reached: \(quartile)", category: .beacon)
    }
    
    func videoPlayer(_ player: CriteoVideoPlayer, didUpdateTime currentTime: TimeInterval, duration: TimeInterval) {
        lastPlaybackPosition = currentTime
        onPlaybackProgress?(currentTime, duration)
    }
    
    func videoPlayerDidReceiveUserInteraction(_ player: CriteoVideoPlayer) {
        wrapperLog("Video user interaction detected", category: .ui)
        onVideoTapped?()
    }
    
    func videoPlayer(_ player: CriteoVideoPlayer, didChangePlaybackState state: VideoPlaybackState) {
        wrapperLog("Video playback state changed: \(state)", category: .video)
        switch state {
        case .playing:
            onVideoStarted?()
        case .paused:
            onVideoPaused?()
        default:
            break
        }
    }
    
    func videoPlayer(_ player: CriteoVideoPlayer, didChangeMuteState isMuted: Bool) {
        // Update saved mute state for persistence across player recreation
        savedMutedState = isMuted
        wrapperLog("Video mute state changed: \(isMuted)", category: .video)
    }
    
    func videoPlayer(_ player: CriteoVideoPlayer, didEncounterError error: Error) {
        wrapperLog("Video player error: \(error)", category: .video)
        currentState = .error(error)
        onVideoError?(error)
    }
    

}

// MARK: - Supporting Types

/// Log categories available for the video ad wrapper
public enum CriteoVideoAdLogCategory: String, CaseIterable, Hashable {
    case vast = "vast"
    case network = "network"
    case video = "video"
    case beacon = "beacon"
    case omid = "omid"
    case ui = "ui"
    
    /// Convert to internal CriteoLogger.Category
    var loggerCategory: CriteoLogger.Category {
        switch self {
        case .vast: return .vast
        case .network: return .network
        case .video: return .video
        case .beacon: return .beacon
        case .omid: return .omid
        case .ui: return .ui
        }
    }
}

/// Configuration options for the video ad wrapper
public struct CriteoVideoAdConfiguration {

    /// Whether to automatically load assets when initialized
    public let autoLoad: Bool

    /// Whether the video should start muted when it first plays
    public let startsMuted: Bool

    /// Background color of the wrapper view
    public let backgroundColor: UIColor
    
    /// Corner radius of the wrapper view
    public let cornerRadius: CGFloat
    
    /// Loading state configuration
    public let loadingBackgroundColor: UIColor
    public let loadingIndicatorColor: UIColor
    public let loadingText: String
    public let loadingTextColor: UIColor
    public let loadingFont: UIFont
    
    /// Error state configuration
    public let errorBackgroundColor: UIColor
    public let errorTextColor: UIColor
    public let errorFont: UIFont
    public let retryButtonText: String
    public let retryButtonColor: UIColor
    public let retryButtonBackgroundColor: UIColor
    public let retryButtonFont: UIFont
    
    /// Initialize configuration with default values for all parameters
    /// Only specify the parameters you want to customize
    public init(
        autoLoad: Bool = true,
        startsMuted: Bool = false,
        backgroundColor: UIColor = .white,
        cornerRadius: CGFloat = 8,
        loadingBackgroundColor: UIColor = .systemGray5,
        loadingIndicatorColor: UIColor = .systemGray2,
        loadingText: String = "Loading video ad...",
        loadingTextColor: UIColor = .systemGray2,
        loadingFont: UIFont = .systemFont(ofSize: 14, weight: .medium),
        errorBackgroundColor: UIColor = .systemGray6,
        errorTextColor: UIColor = .systemRed,
        errorFont: UIFont = .systemFont(ofSize: 14, weight: .medium),
        retryButtonText: String = "Retry",
        retryButtonColor: UIColor = .systemBlue,
        retryButtonBackgroundColor: UIColor = .systemGray5,
        retryButtonFont: UIFont = .systemFont(ofSize: 16, weight: .medium)
    ) {
        self.autoLoad = autoLoad
        self.startsMuted = startsMuted
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.loadingBackgroundColor = loadingBackgroundColor
        self.loadingIndicatorColor = loadingIndicatorColor
        self.loadingText = loadingText
        self.loadingTextColor = loadingTextColor
        self.loadingFont = loadingFont
        self.errorBackgroundColor = errorBackgroundColor
        self.errorTextColor = errorTextColor
        self.errorFont = errorFont
        self.retryButtonText = retryButtonText
        self.retryButtonColor = retryButtonColor
        self.retryButtonBackgroundColor = retryButtonBackgroundColor
        self.retryButtonFont = retryButtonFont
    }
    
    public static let `default` = CriteoVideoAdConfiguration(
        autoLoad: true,
        startsMuted: false,
        backgroundColor: .white,
        cornerRadius: 8,
        loadingBackgroundColor: .systemGray5,
        loadingIndicatorColor: .systemGray2,
        loadingText: "Loading video ad...",
        loadingTextColor: .systemGray2,
        loadingFont: .systemFont(ofSize: 14, weight: .medium),
        errorBackgroundColor: .systemGray6,
        errorTextColor: .systemRed,
        errorFont: .systemFont(ofSize: 14, weight: .medium),
        retryButtonText: "Retry",
        retryButtonColor: .systemBlue,
        retryButtonBackgroundColor: .systemGray5,
        retryButtonFont: .systemFont(ofSize: 16, weight: .medium)
    )
}

/// Current state of the video ad
public enum CriteoVideoAdState: Equatable {
    case notLoaded
    case loading
    case ready
    case error(Error)
    
    public static func == (lhs: CriteoVideoAdState, rhs: CriteoVideoAdState) -> Bool {
        switch (lhs, rhs) {
        case (.notLoaded, .notLoaded):
            return true
        case (.loading, .loading):
            return true
        case (.ready, .ready):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Errors specific to video ad loading
public enum CriteoVideoAdError: LocalizedError {
    case invalidURL(String)
    case noVideoURL
    case vastParsingFailed(String)
    case assetDownloadFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid VAST URL: \(url)"
        case .noVideoURL:
            return "No video URL found in VAST response"
        case .vastParsingFailed(let message):
            return "VAST parsing failed: \(message)"
        case .assetDownloadFailed(let message):
            return "Asset download failed: \(message)"
        }
    }
}

/// Persisted state for resuming playback
private struct CriteoVideoAdPersistedState: Codable {
    let lastPlaybackPosition: TimeInterval
    let isUserPaused: Bool
    let isClosedCaptionsEnabled: Bool?
    let isMuted: Bool?

    // Provide default values for backward compatibility
    var closedCaptionsEnabled: Bool { isClosedCaptionsEnabled ?? true }
    var muted: Bool { isMuted ?? false }
}
