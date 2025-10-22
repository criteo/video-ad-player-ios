//
//  CriteoVideoPlayer.swift
//  OM-Demo
//
//  Created by Serxhio Gugo on 8/22/25.
//  Copyright © 2025 Open Measurement Working Group. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMedia

#if canImport(OMSDK_Criteo)
import OMSDK_Criteo
#endif

// MARK: - Protocols

/// Delegate protocol for CriteoVideoPlayer events
protocol CriteoVideoPlayerDelegate: AnyObject {
    /// Called when video reaches different quartiles
    func videoPlayer(_ player: CriteoVideoPlayer, didReachQuartile quartile: VideoQuartile)
    
    /// Called periodically during playback for time updates
    func videoPlayer(_ player: CriteoVideoPlayer, didUpdateTime currentTime: TimeInterval, duration: TimeInterval)
    
    /// Called when user taps the video for interaction
    func videoPlayerDidReceiveUserInteraction(_ player: CriteoVideoPlayer)
    
    /// Called when playback state changes
    func videoPlayer(_ player: CriteoVideoPlayer, didChangePlaybackState state: VideoPlaybackState)
    
    /// Called when mute state changes
    func videoPlayer(_ player: CriteoVideoPlayer, didChangeMuteState isMuted: Bool)
    
    /// Called when an error occurs
    func videoPlayer(_ player: CriteoVideoPlayer, didEncounterError error: Error)
}

/// Video quartile tracking
enum VideoQuartile: String, CaseIterable {
    case start = "start"
    case firstQuartile = "firstQuartile"
    case midpoint = "midpoint"
    case thirdQuartile = "thirdQuartile"
    case complete = "complete"
    
    var progressThreshold: Double {
        switch self {
        case .start: return 0.0
        case .firstQuartile: return 0.25
        case .midpoint: return 0.5
        case .thirdQuartile: return 0.75
        case .complete: return 1.0
        }
    }
}

/// Playback state
enum VideoPlaybackState {
    case loading
    case playing
    case paused
    case finished
    case error
}

// MARK: - Main Class

/// A reusable, programmatically-built video player component with VAST ad support
final class CriteoVideoPlayer: UIView {
    
    // MARK: - Public Properties
    
    /// Delegate for receiving player events
    weak var delegate: CriteoVideoPlayerDelegate?
    
    /// Enable logging for this player instance (controlled by wrapper)
    var enableInternalLogging: Set<CriteoVideoAdLogCategory> = []
    
    /// Whether closed captions  are currently enabled
    var isClosedCaptionEnabled: Bool = true {
        didSet {
            closedCaptionLabel.isHidden = !isClosedCaptionEnabled
            closedCaptionButton.isSelected = isClosedCaptionEnabled
        }
    }

    /// Whether closed captions  are available for this video (controls CC button visibility)
    var hasClosedCaptionsAvailable: Bool = false {
        didSet {
            closedCaptionButton.isHidden = !hasClosedCaptionsAvailable
        }
    }
    
    /// Whether controls are currently visible
    var areControlsVisible: Bool {
        return !playButton.isHidden
    }
    
    /// Current playback state
    private(set) var playbackState: VideoPlaybackState = .loading {
        didSet {
            delegate?.videoPlayer(self, didChangePlaybackState: playbackState)
        }
    }
    
    /// Current video duration
    var duration: TimeInterval {
        return player?.currentItem?.duration.seconds ?? 0
    }
    
    /// Current playback time
    var currentTime: TimeInterval {
        return player?.currentTime().seconds ?? 0
    }
    
    /// Whether the video is currently muted
    var isMuted: Bool {
        get {
            return player?.isMuted ?? false
        }
        set {
            CriteoLogger.debug("Setting mute state to: \(newValue), player exists: \(player != nil)", category: .video)
            player?.isMuted = newValue
            updateMuteButtonImage(isMuted: newValue)
            delegate?.videoPlayer(self, didChangeMuteState: newValue)
            CriteoLogger.debug("Video mute state set to: \(newValue)", category: .video)
        }
    }
    
    // MARK: - Private Properties
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var timeObserver: Any?
    
    // Closed Caption management
    private let closedCaptionManager = ClosedCaptionsManager()
    
    // OMID session management
    private var omidSessionInteractor: OMIDSessionInteractor?
    
    // Beacon management
    private let beaconManager = BeaconManager()
    private var currentAd: VASTAd?
    private var trackingEvents: [String: URL] = [:]
    
    // Player item reference for manual looping
    private var currentPlayerItem: AVPlayerItem?
    
    // Quartile tracking
    private var currentQuartile: VideoQuartile = .start
    private var hasReachedQuartiles: Set<VideoQuartile> = []
    
    // UI Components
    private let playerContainerView = UIView()
    private let controlsContainerView = UIView()
    private let playButton = UIButton(type: .custom)
    private let muteButton = UIButton(type: .custom)
    private let durationLabel = UILabel()
    private let closedCaptionLabel = UILabel()
    private let closedCaptionButton = UIButton(type: .custom)
    
    // Loading indicator components
    private let loadingContainerView = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()
    
    // Gesture recognizers
    private let tapGestureRecognizer = UITapGestureRecognizer()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
        CriteoLogger.debug("CriteoVideoPlayer initialized", category: .video)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupGestures()
        CriteoLogger.debug("CriteoVideoPlayer initialized from coder", category: .video)
    }
    
    deinit {
        cleanup()
        CriteoLogger.debug("CriteoVideoPlayer deallocated", category: .video)
    }
    
    // MARK: - Public Methods
    
    /// Load and play video from URL
    /// - Parameter videoURL: The URL of the video to play
    func loadVideo(from videoURL: URL) {
        CriteoLogger.info("Loading video from URL", category: .video)

        cleanup() // Clean up any existing player
        showLoadingIndicator() // Show loading indicator

        let playerItem = AVPlayerItem(url: videoURL)
        setupPlayer(with: playerItem) // Manual looping handles all scenarios
        playbackState = .loading
    }
    
    /// Load closed captions  from URL
    /// - Parameter closedCaptionURL: The URL of the WebVTT closed captions file
    func loadClosedCaptions(from closedCaptionURL: URL) {
        CriteoLogger.debug("Loading closed captions from URL", category: .video)
        
        do {
            try closedCaptionManager.load(from: closedCaptionURL)
            CriteoLogger.info("Closed captions loaded successfully", category: .video)
        } catch {
            CriteoLogger.error("Failed to load closed captions: \(error.localizedDescription)", category: .video)
            // Don't treat closed captions loading failure as a critical error
        }
    }
    
    /// Start or resume playback (programmatic - no beacons)
    func play() {
        guard let player = player else { return }
        
        player.play()
        playbackState = .playing
        updatePlayButtonImage(isPlaying: true)
        
        // Fire OMID resume event (if not the first play) - but no beacon
        if hasReachedQuartiles.contains(.start) {
            omidSessionInteractor?.getMediaEventsPublisher().resume()
        }
    }
    

    
    /// Check if video should auto-play when coming into view (respects user pause state)
    func shouldAutoPlay() -> Bool {
        return !isUserPaused
    }

    /// Set the user pause state (used when restoring state from external source)
    func setUserPauseState(_ isPaused: Bool) {
        isUserPaused = isPaused
    }

    /// Set the initial playback position (used when restoring from a saved state)
    func setInitialPlaybackPosition(_ position: TimeInterval) {
        lastPlaybackPosition = position

    }
    
    /// Start or resume playback due to user interaction (fires beacons)
    func playFromUserInteraction() {
        guard let player = player else { return }

        // Clear user pause state when user manually plays
        isUserPaused = false
        onUserPauseStateChanged?(false)

        // If we have a saved position from a previous pause, seek to it first
        if let savedPosition = lastPlaybackPosition, savedPosition > 0 {
            CriteoLogger.info("Seeking to saved position: \(savedPosition)s", category: .video)

            // Use precise seeking for consistent timing accuracy
            seekPreciselyTo(time: savedPosition) { [weak self] finished in
                if finished {
                    // Only start playing after seek is complete
                    self?.player?.play()
                    CriteoLogger.debug("Precise seek completed, starting playback", category: .video)
                } else {
                    // If seek failed, just play from current position
                    self?.player?.play()
                    CriteoLogger.warning("Precise seek failed, playing from current position", category: .video)
                }
            }

            // Clear the saved position after using it
            lastPlaybackPosition = nil
        } else {
            // No saved position, just play immediately
            player.play()
        }

        playbackState = .playing
        updatePlayButtonImage(isPlaying: true)

        // Fire OMID resume event (if not the first play)
        if hasReachedQuartiles.contains(.start) {
            omidSessionInteractor?.getMediaEventsPublisher().resume()
            // Fire resume beacon only for user interactions
            fireBeaconForAction("resume")
        }
    }
    
    /// Pause playback (programmatic - no beacons)
    func pause() {
        guard let player = player else { return }
        
        player.pause()
        playbackState = .paused
        updatePlayButtonImage(isPlaying: false)
        
        // Fire OMID pause event - but no beacon
        omidSessionInteractor?.getMediaEventsPublisher().pause()
    }
    
    /// Pause playback due to user interaction (fires beacons)
    func pauseFromUserInteraction() {
        guard let player = player else { return }

        player.pause()
        playbackState = .paused
        updatePlayButtonImage(isPlaying: false)

        // Save current playback position AFTER pausing for more accuracy
        // Use a slight delay to ensure pause has taken effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self = self, let player = self.player else { return }
            self.lastPlaybackPosition = player.currentTime().seconds
            CriteoLogger.info("User paused at position: \(self.lastPlaybackPosition ?? 0)s", category: .video)
        }

        // Set user pause state to prevent auto-play when scrolling back into view
        isUserPaused = true
        onUserPauseStateChanged?(true)

        // Fire OMID pause event
        omidSessionInteractor?.getMediaEventsPublisher().pause()

        // Fire pause beacon only for user interactions
        fireBeaconForAction("pause")
    }
    
    /// Toggle play/pause state (user interaction - fires beacons)
    func togglePlayPause() {
        guard let player = player else { return }
        
        if player.rate > 0 {
            pauseFromUserInteraction()
        } else {
            playFromUserInteraction()
        }
    }
    
    /// Toggle mute state
    func toggleMute() {
        guard let player = player else { return }
        
        player.isMuted.toggle()
        updateMuteButtonImage(isMuted: player.isMuted)
        delegate?.videoPlayer(self, didChangeMuteState: player.isMuted)
        
        // Fire OMID volume change event
        let volume: CGFloat = player.isMuted ? 0.0 : CGFloat(player.volume)
        omidSessionInteractor?.getMediaEventsPublisher().volumeChange(to: volume)
        
        // Fire mute/unmute beacon
        let beaconType = player.isMuted ? "mute" : "unmute"
        fireBeaconForAction(beaconType)
        
        CriteoLogger.debug("Video mute toggled: \(player.isMuted)", category: .video)
    }
    
    /// Show player controls with animation
    func showControls(animated: Bool = true) {
        let duration = animated ? 0.3 : 0.0
        
        UIView.animate(withDuration: duration) {
            self.controlsContainerView.alpha = 1.0
            self.playButton.isHidden = false
            self.muteButton.isHidden = false
            self.durationLabel.isHidden = false
            self.closedCaptionButton.isHidden = false
        }
    }
    
    /// Hide player controls with animation
    func hideControls(animated: Bool = true) {
        let duration = animated ? 0.3 : 0.0
        
        UIView.animate(withDuration: duration) {
            self.controlsContainerView.alpha = 0.0
        } completion: { _ in
            self.playButton.isHidden = true
            self.muteButton.isHidden = true
            self.durationLabel.isHidden = true
            self.closedCaptionButton.isHidden = true
        }
    }
    
    /// Show loading indicator
    func showLoadingIndicator() {
        playerContainerView.bringSubviewToFront(loadingContainerView)
        loadingContainerView.isHidden = false
        loadingSpinner.startAnimating()
        controlsContainerView.alpha = 0.0
    }
    
    /// Hide loading indicator
    func hideLoadingIndicator() {
        loadingContainerView.isHidden = true
        loadingSpinner.stopAnimating()
        controlsContainerView.alpha = 1.0
    }
    
    // MARK: - OMID Integration
    
    /// Set VAST ad data for beacon tracking
    /// - Parameter ad: The VAST ad data
    func setVASTAd(_ ad: VASTAd) {
        currentAd = ad
        trackingEvents = ad.trackingEvents
        CriteoLogger.debug("VAST ad data set for beacon tracking", category: .video)
    }
    
    /// Initialize OMID session for ad measurement
    /// - Parameters:
    ///   - vendorKey: Vendor identifier from VAST
    ///   - verificationScriptURL: Script URL from VAST
    ///   - verificationParameters: Parameters from VAST
    func setupOMIDSession(vendorKey: String, verificationScriptURL: String, verificationParameters: String) {
        CriteoLogger.info("Setting up OMID session", category: .video)
        
        omidSessionInteractor = OMIDSessionInteractor(
            adView: playerContainerView,
            vendorKey: vendorKey,
            verificationScriptURL: verificationScriptURL,
            verificationParameters: verificationParameters
        )
        
        // Register UI controls as friendly obstructions
        registerFriendlyObstructions()
        
        // Start the OMID session
        omidSessionInteractor?.startSession()
        
        // Fire ad loaded event
        #if canImport(OMSDK_Criteo)
        let vastProperties = OMIDCriteoVASTProperties(autoPlay: true, position: .standalone)
        omidSessionInteractor?.fireAdLoaded(vastProperties: vastProperties)
        #endif
        
        CriteoLogger.info("OMID session started successfully", category: .video)
    }
    
    /// Register UI controls as friendly obstructions for OMID
    private func registerFriendlyObstructions() {
        guard let sessionInteractor = omidSessionInteractor else { return }
        
        // Register all control buttons as media controls obstructions
        sessionInteractor.addMediaControlsObstruction(playButton)
        sessionInteractor.addMediaControlsObstruction(muteButton)
        sessionInteractor.addMediaControlsObstruction(durationLabel)
        sessionInteractor.addMediaControlsObstruction(closedCaptionButton)
        sessionInteractor.addMediaControlsObstruction(closedCaptionLabel)
        
        CriteoLogger.debug("Registered UI controls as OMID friendly obstructions", category: .video)
    }
    
    /// Fire impression events (call when video starts playing)
    func fireImpressionEvents() {
        // Fire OMID impression
        omidSessionInteractor?.fireImpression()
        
        // Fire beacon impression tracking
        if let ad = currentAd {
            Task { @MainActor in
                beaconManager.fireImpressionBeacons(from: ad)
            }
        }
        
        CriteoLogger.info("Impression events fired", category: .video)
    }
    

    
    /// Stop OMID session (call when video player is being deallocated)
    func stopOMIDSession() {
        guard omidSessionInteractor != nil else { return }
        omidSessionInteractor?.stopSession()
        omidSessionInteractor = nil
        CriteoLogger.info("OMID session stopped", category: .video)
    }
    

    /// Clean up resources
    func cleanup() {
        
        // Stop OMID session
        stopOMIDSession()
        
        // Remove time observer
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Remove any pending observers
        if let player = player, pendingSeekTime != nil {
            player.removeObserver(self, forKeyPath: "status", context: &CriteoVideoPlayer.seekContext)
            pendingSeekTime = nil
        }
        
        // Stop playback and clean up player
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        
        // Reset state
        player = nil
        playerLayer = nil
        currentPlayerItem = nil
        hasReachedQuartiles.removeAll()
        currentQuartile = .start
        playbackState = .loading
        // Note: Don't reset isUserPaused here - it should persist across cleanup
        // so the table controller can check it and preserve user's pause intention
    }
    
    /// Get current playback time in seconds
    func getCurrentTime() -> TimeInterval {
        guard let player = player else { return 0.0 }
        return player.currentTime().seconds
    }
    
    /// Seek to a specific time in the video
    func seekTo(time: TimeInterval) {
        guard let player = player else {
            CriteoLogger.error("seekTo failed: player is nil", category: .video)
            return
        }
        
        guard time >= 0 else {
            CriteoLogger.error("seekTo failed: invalid time \(time)", category: .video)
            return
        }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        player.seek(to: cmTime) { finished in
            if !finished {
                CriteoLogger.error("Seek to \(time)s failed or was interrupted", category: .video)
            }
        }
    }

    /// Seek to a specific time with high precision (for consistent timing across all playback scenarios)
    /// - Parameters:
    ///   - time: The time in seconds to seek to
    ///   - completion: Optional completion handler called when seek finishes
    func seekPreciselyTo(time: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        guard let player = player else {
            CriteoLogger.error("seekPreciselyTo failed: player is nil", category: .video)
            completion?(false)
            return
        }

        guard time >= 0 else {
            CriteoLogger.error("seekPreciselyTo failed: invalid time \(time)", category: .video)
            completion?(false)
            return
        }

        CriteoLogger.debug("Seeking precisely to \(time)s", category: .video)

        // Use higher precision timescale and zero tolerance for frame accuracy
        let seekTime = CMTime(seconds: time, preferredTimescale: 1000)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            if finished {
                CriteoLogger.debug("Precise seek to \(time)s completed successfully", category: .video)
            } else {
                CriteoLogger.error("Precise seek to \(time)s failed or was interrupted", category: .video)
            }
            completion?(finished)
        }
    }

    /// Force an immediate update of the duration label with current playback state
    /// Useful when restoring player state to show correct time display
    func updateDurationLabelImmediately(currentTime: TimeInterval, duration: TimeInterval) {
        updateDurationLabel(currentTime: currentTime, duration: duration)
    }

    /// Observe player status changes
    /// - Parameter callback: Called when player status changes
    func observePlayerStatus(_ callback: @escaping (AVPlayer.Status) -> Void) {
        guard let player = player else { return }

        // Remove any existing observer for this key
        player.removeObserver(self, forKeyPath: "status", context: &CriteoVideoPlayer.statusContext)

        // Add new observer
        player.addObserver(self, forKeyPath: "status", options: [.new], context: &CriteoVideoPlayer.statusContext)

        // Store the callback to be called when status changes
        playerStatusCallback = callback
    }

    // Context for status KVO
    private static var statusContext = 0
    private var playerStatusCallback: ((AVPlayer.Status) -> Void)?
    
    // Context for KVO observation
    private static var seekContext = 0
    private var pendingSeekTime: TimeInterval?
    
    // Track user pause state to prevent auto-play when user manually paused
    private var isUserPaused: Bool = false

    // Track the last playback position for resuming after manual pause
    private var lastPlaybackPosition: TimeInterval?

    // Callback for user pause state changes
    var onUserPauseStateChanged: ((Bool) -> Void)?
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if context == &CriteoVideoPlayer.seekContext {
            if keyPath == "status", let player = object as? AVPlayer {
                if player.status == .readyToPlay, let seekTime = pendingSeekTime {
                    // Remove observer
                    player.removeObserver(self, forKeyPath: "status", context: &CriteoVideoPlayer.seekContext)
                    pendingSeekTime = nil

                    // Perform seek and play (only if not user paused)
                    seekTo(time: seekTime)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Only play if not user paused
                        if !self.isUserPaused {
                            CriteoLogger.info("🎬 KVO: Starting playback after seek (user not paused)", category: .video)
                            self.play()
                        } else {
                            CriteoLogger.info("⏸️ KVO: Staying paused after seek (user paused)", category: .video)
                        }
                    }
                } else if player.status == .failed {
                    CriteoLogger.error("Player failed to load", category: .video)
                    player.removeObserver(self, forKeyPath: "status", context: &CriteoVideoPlayer.seekContext)
                    pendingSeekTime = nil
                }
            }

        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

// MARK: - Private Setup Methods

private extension CriteoVideoPlayer {
    
    func setupUI() {
        backgroundColor = .black
        setupPlayerContainer()
        setupControls()
        setupClosedCaptionsLabel()
        setupLoadingIndicator()
        setupLayout()
    }
    
    func setupPlayerContainer() {
        playerContainerView.backgroundColor = .black
        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playerContainerView)
    }
    
    func setupControls() {
        // Controls container
        controlsContainerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(controlsContainerView)
        
        // Play/Pause button
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setImage(UIImage(systemName: "play.fill")?.withTintColor(.darkGray, renderingMode: .alwaysOriginal), for: .normal)
        playButton.backgroundColor = UIColor.lightGray
        playButton.layer.cornerRadius = 4
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        controlsContainerView.addSubview(playButton)
        
        // Mute button
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.setImage(UIImage(systemName: "speaker.wave.2.fill")?.withTintColor(.darkGray, renderingMode: .alwaysOriginal), for: .normal)
        muteButton.backgroundColor = UIColor.lightGray
        muteButton.layer.cornerRadius = 4
        muteButton.addTarget(self, action: #selector(muteButtonTapped), for: .touchUpInside)
        controlsContainerView.addSubview(muteButton)
        
        // Duration label
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.text = "00:00"
        durationLabel.textColor = .white
        durationLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        durationLabel.textAlignment = .center
        durationLabel.backgroundColor = UIColor.lightGray
        durationLabel.layer.cornerRadius = 4
        durationLabel.clipsToBounds = true
        controlsContainerView.addSubview(durationLabel)
        
        // Closed caption toggle button
        closedCaptionButton.translatesAutoresizingMaskIntoConstraints = false
        closedCaptionButton.setTitle("CC", for: .normal)
        closedCaptionButton.setTitleColor(.darkGray, for: .normal)
        closedCaptionButton.setTitleColor(.white, for: .selected)
        closedCaptionButton.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        closedCaptionButton.backgroundColor = UIColor.lightGray
        closedCaptionButton.layer.cornerRadius = 4 // Same as other controls
        closedCaptionButton.isSelected = isClosedCaptionEnabled
        closedCaptionButton.addTarget(self, action: #selector(closedCaptionButtonTapped), for: .touchUpInside)
        controlsContainerView.addSubview(closedCaptionButton)
    }
    
    func setupClosedCaptionsLabel() {
        closedCaptionLabel.translatesAutoresizingMaskIntoConstraints = false
        closedCaptionLabel.textColor = .white
        closedCaptionLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        closedCaptionLabel.textAlignment = .center
        closedCaptionLabel.numberOfLines = 2
        closedCaptionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        closedCaptionLabel.layer.cornerRadius = 4
        closedCaptionLabel.clipsToBounds = true
        
        // Reduce padding by setting content insets
        closedCaptionLabel.layoutMargins = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        closedCaptionLabel.insetsLayoutMarginsFromSafeArea = false

        // Hide by default - only show when there are actual closed captions
        closedCaptionLabel.isHidden = true

        addSubview(closedCaptionLabel)
    }
    
    func setupLoadingIndicator() {
        // Loading container
        loadingContainerView.translatesAutoresizingMaskIntoConstraints = false
        loadingContainerView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.95)
        loadingContainerView.layer.cornerRadius = 12
        loadingContainerView.layer.borderWidth = 1
        loadingContainerView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        loadingContainerView.isHidden = true
        playerContainerView.addSubview(loadingContainerView)
        
        // Ensure loading indicator is on top
        playerContainerView.bringSubviewToFront(loadingContainerView)
        
        // Loading spinner
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.color = .white
        loadingContainerView.addSubview(loadingSpinner)
        
        // Loading label
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.text = "Loading video..."
        loadingLabel.textColor = .white
        loadingLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        loadingLabel.textAlignment = .center
        loadingContainerView.addSubview(loadingLabel)
    }
    
    func setupGestures() {
        tapGestureRecognizer.addTarget(self, action: #selector(viewTapped))
        addGestureRecognizer(tapGestureRecognizer)
    }
    
    func setupLayout() {
        NSLayoutConstraint.activate([
            // Player container - fills entire view
            playerContainerView.topAnchor.constraint(equalTo: topAnchor),
            playerContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            playerContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Controls container - overlays on player
            controlsContainerView.topAnchor.constraint(equalTo: topAnchor),
            controlsContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            controlsContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            controlsContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Play button - bottom left (smaller size)
            playButton.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 12),
            playButton.bottomAnchor.constraint(equalTo: controlsContainerView.bottomAnchor, constant: -12),
            playButton.widthAnchor.constraint(equalToConstant: 28),
            playButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Mute button - bottom left, next to play button (smaller size)
            muteButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 6),
            muteButton.bottomAnchor.constraint(equalTo: controlsContainerView.bottomAnchor, constant: -12),
            muteButton.widthAnchor.constraint(equalToConstant: 28),
            muteButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Duration label - top right (smaller size)
            durationLabel.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -12),
            durationLabel.topAnchor.constraint(equalTo: controlsContainerView.topAnchor, constant: 12),
            durationLabel.widthAnchor.constraint(equalToConstant: 44),
            durationLabel.heightAnchor.constraint(equalToConstant: 28),
            
            // Closed caption button - top left
            closedCaptionButton.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 12),
            closedCaptionButton.topAnchor.constraint(equalTo: controlsContainerView.topAnchor, constant: 12),
            closedCaptionButton.widthAnchor.constraint(equalToConstant: 28),
            closedCaptionButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Closed Captions label - positioned to the right of volume button with more space
            closedCaptionLabel.leadingAnchor.constraint(equalTo: muteButton.trailingAnchor, constant: 8),
            closedCaptionLabel.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -12),
            closedCaptionLabel.bottomAnchor.constraint(equalTo: muteButton.bottomAnchor),
            closedCaptionLabel.heightAnchor.constraint(equalToConstant: 36),
            
            // Loading indicator - centered in player container
            loadingContainerView.centerXAnchor.constraint(equalTo: playerContainerView.centerXAnchor),
            loadingContainerView.centerYAnchor.constraint(equalTo: playerContainerView.centerYAnchor),
            loadingContainerView.widthAnchor.constraint(equalToConstant: 180),
            loadingContainerView.heightAnchor.constraint(equalToConstant: 100),
            
            // Loading spinner constraints
            loadingSpinner.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            loadingSpinner.topAnchor.constraint(equalTo: loadingContainerView.topAnchor, constant: 16),
            
            // Loading label constraints
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: loadingSpinner.bottomAnchor, constant: 8),
            loadingLabel.leadingAnchor.constraint(equalTo: loadingContainerView.leadingAnchor, constant: 8),
            loadingLabel.trailingAnchor.constraint(equalTo: loadingContainerView.trailingAnchor, constant: -8)
        ])
    }
}

// MARK: - Private Player Setup

private extension CriteoVideoPlayer {
    
    func setupPlayer(with item: AVPlayerItem) {
        // Store reference to player item for manual looping
        self.currentPlayerItem = item
        
        // Create regular AVPlayer instead of AVQueuePlayer for better control
        let player = AVPlayer(playerItem: item)
        self.player = player
        
        // Manual looping through time observer for full control
        
        // Create and setup player layer
        let layer = AVPlayerLayer(player: player)
        layer.frame = playerContainerView.bounds
        layer.videoGravity = .resizeAspect
        playerContainerView.layer.addSublayer(layer)
        self.playerLayer = layer
        
        // Setup time observer
        setupTimeObserver()
        
        // Start playback only if not user paused
        if !isUserPaused {
            CriteoLogger.info("🎬 setupPlayer: Starting playback (user not paused)", category: .video)
            player.play()
            playbackState = .playing
            updatePlayButtonImage(isPlaying: true)
        } else {
            CriteoLogger.info("⏸️ setupPlayer: Keeping paused (user paused)", category: .video)
            // User paused - keep in paused state
            playbackState = .paused
            updatePlayButtonImage(isPlaying: false)
        }

        // Hide loading indicator
        hideLoadingIndicator()
        
        CriteoLogger.info("Video player setup completed", category: .video)
    }
    

    
    func setupTimeObserver() {
        guard let player = player else { return }
        
        // Remove existing observer
        if let existingObserver = timeObserver {
            player.removeTimeObserver(existingObserver)
        }
        
        // Add new observer - fires every 0.1 seconds for precise closed captions timing
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.handleTimeUpdate(time)
        }
    }
    
    func handleTimeUpdate(_ time: CMTime) {
        guard let player = player,
              let currentItem = player.currentItem else { return }
        
        let currentTime = time.seconds
        let duration = currentItem.duration.seconds
        
        // Update duration label
        updateDurationLabel(currentTime: currentTime, duration: duration)
        
        // Update closedCaptions
        updateClosedCaptions(at: time)
        
        // Check quartile progress only when actually playing
        if playbackState == .playing {
            checkQuartileProgress(currentTime: currentTime, duration: duration)
        }
        
        // Notify delegate
        delegate?.videoPlayer(self, didUpdateTime: currentTime, duration: duration)
        
        // Handle manual video looping
        if currentTime >= duration && duration > 0 {
            player.seek(to: .zero) { [weak self] finished in
                if finished {
                    // Ensure video continues playing after seek
                    self?.player?.play()
                }
            }
        }
    }
    
    func updateDurationLabel(currentTime: TimeInterval, duration: TimeInterval) {
        let timeLeft = max(0, duration - currentTime)
        let minutes = Int(timeLeft) / 60
        let seconds = Int(timeLeft) % 60
        durationLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    func updateClosedCaptions(at time: CMTime) {
        guard isClosedCaptionEnabled else {
            closedCaptionLabel.text = ""
            closedCaptionLabel.isHidden = true
            return
        }

        let closedCaptionText = closedCaptionManager.text(at: time) ?? ""
        closedCaptionLabel.text = closedCaptionText

        // Hide closed captions label when there's no text to display (even when CC is enabled)
        // This prevents showing an empty background when there are no closed captions
        closedCaptionLabel.isHidden = closedCaptionText.isEmpty
    }
    
    func checkQuartileProgress(currentTime: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else { return }
        
        let progress = currentTime / duration
        
        for quartile in VideoQuartile.allCases {
            if progress >= quartile.progressThreshold && !hasReachedQuartiles.contains(quartile) {
                hasReachedQuartiles.insert(quartile)
                currentQuartile = quartile
                delegate?.videoPlayer(self, didReachQuartile: quartile)
                
                // Fire OMID media events for quartiles
                fireOMIDMediaEvent(for: quartile, duration: duration)
            }
        }
    }
    
    private func fireOMIDMediaEvent(for quartile: VideoQuartile, duration: TimeInterval) {
        guard let mediaEvents = omidSessionInteractor?.getMediaEventsPublisher() else { return }
        
        switch quartile {
        case .start:
            let volume: CGFloat = player?.isMuted == true ? 0.0 : CGFloat(player?.volume ?? 1.0)
            mediaEvents.start(withDuration: CGFloat(duration), mediaPlayerVolume: volume)
            fireBeacon(for: .start)
            
        case .firstQuartile:
            mediaEvents.firstQuartile()
            fireBeacon(for: .firstQuartile)
            
        case .midpoint:
            mediaEvents.midpoint()
            fireBeacon(for: .midpoint)
            
        case .thirdQuartile:
            mediaEvents.thirdQuartile()
            fireBeacon(for: .thirdQuartile)
            
        case .complete:
            mediaEvents.complete()
            fireBeacon(for: .complete)
        }
    }
    
    private func fireBeacon(for quartile: VideoQuartile) {
        let beaconType: String
        
        switch quartile {
        case .start:
            beaconType = "start"
        case .firstQuartile:
            beaconType = "firstQuartile"
        case .midpoint:
            beaconType = "midpoint"
        case .thirdQuartile:
            beaconType = "thirdQuartile"
        case .complete:
            beaconType = "complete"
        }
        
        guard let url = trackingEvents[beaconType] else {
            playerLog("No beacon URL found for type: \(beaconType)", category: .beacon)
            return
        }
        
        Task { @MainActor in
            beaconManager.fireBeacon(url: url, type: beaconType)
        }
    }
    
    private func fireBeaconForAction(_ actionType: String) {
        guard let url = trackingEvents[actionType] else {
            playerLog("No beacon URL found for action type: \(actionType)", category: .beacon)
            return
        }
        
        Task { @MainActor in
            beaconManager.fireBeacon(url: url, type: actionType)
        }
    }
    
    /// Handle video click - fires OMID/beacon events and either opens URL or toggles play/pause
    private func handleVideoClick() {
        // Always fire OMID click event
        #if canImport(OMSDK_Criteo)
        omidSessionInteractor?.getMediaEventsPublisher().adUserInteraction(withType: .click)
        #endif
        
        // Fire click tracking beacons
        if let ad = currentAd {
            Task { @MainActor in
                beaconManager.fireClickTrackingBeacons(from: ad)
            }
        }
        
        // Check if there's a click-through URL
        if let clickThroughURL = getClickThroughURL() {
            // Open the URL if it exists
            UIApplication.shared.open(clickThroughURL, options: [:]) { success in
                if !success {
                    CriteoLogger.warning("Failed to open click-through URL: \(clickThroughURL)", category: .video)
                }
            }
            CriteoLogger.debug("Opening click-through URL: \(clickThroughURL)", category: .video)
        } else {
            // No click-through URL available, use tap as pause/resume toggle
            togglePlayPause()
            CriteoLogger.debug("No click-through URL found, toggling play/pause instead", category: .video)
        }
    }
    
    /// Get click-through URL from VAST ad data
    /// - Returns: Valid click-through URL or nil
    private func getClickThroughURL() -> URL? {
        guard let ad = currentAd else { return nil }
        
        // Get the click-through URL from VAST ad
        guard let clickThroughURL = ad.clickThroughURL else { return nil }
        
        // Check if URL already has a scheme
        if let scheme = clickThroughURL.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            return clickThroughURL
        }
        
        // If no scheme, assume https and create a proper URL
        let urlString = clickThroughURL.absoluteString
        if let properURL = URL(string: "https://\(urlString)") {
            CriteoLogger.debug("Added https:// scheme to URL: \(urlString) -> \(properURL)", category: .video)
            return properURL
        }
        
        CriteoLogger.error("Failed to create valid URL from: \(urlString)", category: .video)
        return nil
    }
    

}

// MARK: - Private UI Updates

private extension CriteoVideoPlayer {
    
    func updatePlayButtonImage(isPlaying: Bool) {
        let symbolName = isPlaying ? "pause.fill" : "play.fill"
        let image = UIImage(systemName: symbolName)?.withTintColor(.darkGray, renderingMode: .alwaysOriginal)
        playButton.setImage(image, for: .normal)
    }
    
    func updateMuteButtonImage(isMuted: Bool) {
        let symbolName = isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        let image = UIImage(systemName: symbolName)?.withTintColor(.darkGray, renderingMode: .alwaysOriginal)
        muteButton.setImage(image, for: .normal)
    }
}

// MARK: - Logging Helper

extension CriteoVideoPlayer {
    private func playerLog(_ message: String, category: CriteoVideoAdLogCategory) {
        guard enableInternalLogging.contains(category) else { return }
        CriteoLogger.info("[Player] \(message)", category: category.loggerCategory)
    }
}

// MARK: - Action Handlers

private extension CriteoVideoPlayer {
    
    @objc func playButtonTapped() {
        playerLog("Play button tapped", category: .ui)
        togglePlayPause()
    }
    
    @objc func muteButtonTapped() {
        playerLog("Mute button tapped", category: .ui)
        toggleMute()
    }
    
    @objc func closedCaptionButtonTapped() {
        playerLog("Closed caption button tapped", category: .ui)
        isClosedCaptionEnabled.toggle()
        playerLog("Closed captions toggled: \(isClosedCaptionEnabled)", category: .video)
    }
    
    @objc func viewTapped() {
        playerLog("Video view tapped", category: .ui)
        
        // Handle video click for OMID and beacon tracking
        handleVideoClick()
        
        delegate?.videoPlayerDidReceiveUserInteraction(self)
        playerLog("Video player received user interaction", category: .video)
    }
}

// MARK: - Layout

extension CriteoVideoPlayer {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update player layer frame
        playerLayer?.frame = playerContainerView.bounds
    }
}

