//
//  CriteoAdSwiftUIListView_Sample.swift
//  OM-Demo
//
//  Simple SwiftUI List example showing video ad integration
//  Demonstrates basic video ad in a scrollable feed
//

import SwiftUI
import Foundation

struct CriteoAdSwiftUIListView_Sample: View {
    @StateObject private var viewModel = VideoAdViewModel(vastURL: Constants.vastURL)

    var body: some View {
        NavigationView {
            List(0..<20, id: \.self) { index in
                if index == 12 { // Video ad at position 12
                    VideoAdCell(wrapper: viewModel.wrapper)
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                } else {
                    // Regular content cell
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content Item #\(index)")
                            .font(.headline)
                        Text("Scroll down to see the video ad...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            // Start preloading immediately when view appears (like UIKit viewDidLoad)
            viewModel.startVideoPreloading()
        }
        .onDisappear {
            // Cleanup when entire view disappears (navigating back)
            NotificationCenter.default.post(name: NSNotification.Name("SwiftUIViewDisappeared"), object: nil)
        }
    }

}

// MARK: - Video Ad Cell
struct VideoAdCell: View {
    let wrapper: CriteoVideoAdWrapper

    var body: some View {
        ZStack {
            // Simple video player - use preloaded shared wrapper
            CriteoVideoAdSwiftUIView(wrapper: wrapper)
        }
        .onAppear {
            // Signal that cell appeared - start playing if loaded
            NotificationCenter.default.post(name: NSNotification.Name("VideoCellAppeared"), object: nil)
        }
        .onDisappear {
            // Signal that cell disappeared (don't cleanup yet, just pause)
            NotificationCenter.default.post(name: NSNotification.Name("VideoCellDisappeared"), object: nil)
        }
    }
}

// MARK: - UIViewRepresentable Wrapper
struct CriteoVideoAdSwiftUIView: UIViewRepresentable {
    let wrapper: CriteoVideoAdWrapper

    func makeUIView(context: Context) -> CriteoVideoAdWrapper {
        context.coordinator.wrapper = wrapper
        setupWrapperCallbacks(wrapper, coordinator: context.coordinator)
        return wrapper
    }

    func updateUIView(_ uiView: CriteoVideoAdWrapper, context: Context) {
        // No updates needed - preloading happens in makeUIView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func setupWrapperCallbacks(_ wrapper: CriteoVideoAdWrapper, coordinator: Coordinator) {
        // Mirror UIKit callback setup
        wrapper.onVideoLoaded = {
            CriteoLogger.debug("Video loaded - ready to play when visible", category: .video)
        }

        wrapper.onVideoError = { error in
            CriteoLogger.error("Video error - \(error.localizedDescription)", category: .video)
        }

        wrapper.onVideoStarted = {
            CriteoLogger.debug("Video started playing", category: .video)
        }

        wrapper.onVideoPaused = {
            CriteoLogger.debug("Video paused", category: .video)
        }

        // Track user-initiated pause state (mirrors UIKit implementation)
        wrapper.onUserPauseStateChanged = { isPaused in
            CriteoLogger.debug("User pause state changed - \(isPaused)", category: .video)
            // The wrapper handles this internally, we don't need to store it separately
        }

        // Add more detailed callbacks for debugging
        wrapper.onPlaybackProgress = { currentTime, duration in
            if Int(currentTime) % 5 == 0 && Int(currentTime) > 0 {
                CriteoLogger.debug("Playback progress - \(String(format: "%.1f", currentTime))/\(String(format: "%.1f", duration))", category: .video)
            }
        }
    }

    // MARK: - Coordinator
    class Coordinator {
        var wrapper: CriteoVideoAdWrapper?

        init() {
            // Listen for visibility notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleCellAppeared),
                name: NSNotification.Name("VideoCellAppeared"),
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleCellDisappeared),
                name: NSNotification.Name("VideoCellDisappeared"),
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleViewDisappeared),
                name: NSNotification.Name("SwiftUIViewDisappeared"),
                object: nil
            )
        }

        @objc private func handleCellAppeared() {
            CriteoLogger.debug("Video cell appeared - resuming playback", category: .video)
            if let wrapper = wrapper {
                CriteoLogger.debug("Wrapper exists, attempting to resume playback...", category: .video)
                // Always resume when cell appears (mirror UIKit behavior)
                wrapper.resumePlayback()
                CriteoLogger.debug("resumePlayback() called", category: .video)
            } else {
                CriteoLogger.error("No wrapper available for resume", category: .video)
            }
        }

        @objc private func handleCellDisappeared() {
            CriteoLogger.debug("Video cell disappeared - pausing and detaching", category: .video)
            if let wrapper = wrapper {
                // This properly cleans up resources without marking as user-paused
                wrapper.pauseAndDetach()
            }
        }

        @objc private func handleViewDisappeared() {
            CriteoLogger.debug("View disappeared - full cleanup", category: .video)
            if let wrapper = wrapper {
                // Stop playback and clean up
                wrapper.pauseAndDetach()
                wrapper.removeFromSuperview()

                // Clear all callbacks to prevent retain cycles
                wrapper.onVideoLoaded = nil
                wrapper.onVideoError = nil
                wrapper.onVideoStarted = nil
                wrapper.onVideoPaused = nil
                wrapper.onUserPauseStateChanged = nil
                wrapper.onPlaybackProgress = nil
            }
            wrapper = nil
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}


// MARK: - ViewModel for preloading and sharing wrapper
final class VideoAdViewModel: ObservableObject {
    let wrapper: CriteoVideoAdWrapper
    private var hasStartedPreloading = false

    init(vastURL: String) {
        // Create a single shared wrapper without persistence
        let config = CriteoVideoAdConfiguration(
            autoLoad: false,
            startsMuted: true,
            backgroundColor: .white,
            cornerRadius: 8
        )
        self.wrapper = CriteoVideoAdWrapper(
            vastURL: vastURL,
            identifier: nil,
            configuration: config
        )
    }

    func startVideoPreloading() {
        CriteoLogger.debug("Starting video preloading immediately", category: .video)
        guard !hasStartedPreloading else { return }
        hasStartedPreloading = true
        wrapper.preloadAssets()
    }
}

// MARK: - Preview
struct SwiftUIListExamples_Previews: PreviewProvider {
    static var previews: some View {
        CriteoAdSwiftUIListView_Sample()
    }
}
