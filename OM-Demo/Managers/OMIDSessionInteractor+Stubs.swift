//
//  OMIDSessionInteractor+Stubs.swift
//  OM-Demo
//
//  Created by Serxhio Gugo on 11/29/25.
//  Copyright © 2025 Open Measurement Working Group. All rights reserved.
//

// Note: This file provides a no-op fallback for OMID. It is compiled only when
// OMSDK_Criteo cannot be imported (see the #if !canImport(OMSDK_Criteo) guard below).
// This allows the project to build and run even when OMID is not present.

#if !canImport(OMSDK_Criteo)
import Foundation
import UIKit

final class OMIDSessionInteractor {

    private let adView: UIView?
    private var adEvents = AdEventsNoOp()
    private var mediaEvents = MediaEventsNoOp()

    init(adView: UIView? = nil, vendorKey: String, verificationScriptURL: String, verificationParameters: String) {
        self.adView = adView
        CriteoLogger.info("[OMID-Stub] init vendorKey=\(vendorKey) url=\(verificationScriptURL)", category: .omid)
    }

    func startSession() {
        CriteoLogger.info("[OMID-Stub] startSession", category: .omid)
    }

    func addMediaControlsObstruction(_ element: UIView) {
        CriteoLogger.debug("[OMID-Stub] addMediaControlsObstruction: \(type(of: element))", category: .omid)
    }

    func fireAdLoaded() {
        CriteoLogger.info("[OMID-Stub] fireAdLoaded", category: .omid)
        adEvents.loaded()
    }

    func fireImpression() {
        CriteoLogger.info("[OMID-Stub] fireImpression", category: .omid)
        adEvents.impressionOccurred()
    }

    func stopSession() {
        CriteoLogger.info("[OMID-Stub] stopSession", category: .omid)
    }

    // Publisher shims
    func getMediaEventsPublisher() -> MediaEventsNoOp { mediaEvents }
    func getAdEventsPublisher() -> AdEventsNoOp { adEvents }

    @discardableResult
    static func activateOMSDK() -> Bool {
        CriteoLogger.info("[OMID-Stub] activateOMSDK (noop)", category: .omid)
        return true
    }

    static func prefetchOMIDSDK() {
        CriteoLogger.info("[OMID-Stub] prefetchOMIDSDK (noop)", category: .omid)
    }

    // MARK: - No-op Ad/Media events
    final class AdEventsNoOp {
        func loaded() { CriteoLogger.debug("[OMID-Stub] AdEvents.loaded()", category: .omid) }
        func impressionOccurred() { CriteoLogger.debug("[OMID-Stub] AdEvents.impressionOccurred()", category: .omid) }
    }

    final class MediaEventsNoOp {
        func start(withDuration: CGFloat, mediaPlayerVolume: CGFloat) {
            CriteoLogger.debug("[OMID-Stub] MediaEvents.start(duration=\(withDuration), volume=\(mediaPlayerVolume))", category: .omid)
        }
        func firstQuartile() { CriteoLogger.debug("[OMID-Stub] MediaEvents.firstQuartile()", category: .omid) }
        func midpoint() { CriteoLogger.debug("[OMID-Stub] MediaEvents.midpoint()", category: .omid) }
        func thirdQuartile() { CriteoLogger.debug("[OMID-Stub] MediaEvents.thirdQuartile()", category: .omid) }
        func complete() { CriteoLogger.debug("[OMID-Stub] MediaEvents.complete()", category: .omid) }
        func resume() { CriteoLogger.debug("[OMID-Stub] MediaEvents.resume()", category: .omid) }
        func pause() { CriteoLogger.debug("[OMID-Stub] MediaEvents.pause()", category: .omid) }
        func volumeChange(to: CGFloat) { CriteoLogger.debug("[OMID-Stub] MediaEvents.volumeChange(to=\(to))", category: .omid) }
        func adUserInteraction(withType: Any? = nil) {
            CriteoLogger.debug("[OMID-Stub] MediaEvents.adUserInteraction(type=\(String(describing: withType)))", category: .omid)
        }
    }
}
#endif

