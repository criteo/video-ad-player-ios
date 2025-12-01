//
//  OMIDHelper.swift
//  OM-TestApp
//
//  Created by Michele Simone on 14/11/2022.
//  Copyright © 2022 IAB Techlab. All rights reserved.
//

import Foundation
import UIKit

#if canImport(OMSDK_Criteo)
import OMSDK_Criteo
#endif

// WebKit is only needed when OMSDK is available
#if canImport(OMSDK_Criteo)
import WebKit
#endif


/// Utility wrapper around the OMID SDK, for demo purpose only.
/// Not to be used in a production integration
#if canImport(OMSDK_Criteo)
class OMIDSessionInteractor {

    private var adEvents: OMIDCriteoAdEvents?
    private var mediaEvents: OMIDCriteoMediaEvents?
    private let adView: UIView?

    private let adSession: OMIDCriteoAdSession

    /// Uniquely identify your integration.
    private static var partner: OMIDCriteoPartner = {
        // The IAB Tech Lab will assign a unique partner name to you at the time of integration.
        let partnerName = "TestApp"
        // For an ads SDK, this should be the same as your SDK’s semantic version. For an app publisher, this should be the same as your app version.
        let partnerVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        guard let partner = OMIDCriteoPartner(name: partnerName, versionString: partnerVersion ?? "1.0") else {
            fatalError("Unable to initialize OMID partner")
        }

        return partner
    }()


    /// Creates an OMID Utility object
    /// - Parameters:
    ///   - adView: The ad view
    ///   - webViewContext: The webView where the OMID Context is running if not managed natively.
    init(adView: UIView? = nil, vendorKey:String, verificationScriptURL: String, verificationParameters: String) {
        self.adView = adView
        self.adSession = OMIDSessionInteractor.createAdSession(adView: adView, vendorKey: vendorKey, verificationScriptURL: verificationScriptURL, verificationParameters: verificationParameters)
    }

    private static func createAdSession(adView: UIView?, vendorKey:String, verificationScriptURL: String, verificationParameters: String) -> OMIDCriteoAdSession {
        // ensure OMID has been already activated
        guard OMIDCriteoSDK.shared.isActive else {
            fatalError("OMID is not active")
        }

        // Obtain ad session context. The context may be different depending on the type of the ad unit.
        let context = createAdSessionContext(withPartner: partner, adView: adView, vendorKey: vendorKey, verificationScriptURL: verificationScriptURL, verificationParameters: verificationParameters)

        // Obtain ad session configuration. Configuration may be different depending on the type of the ad unit.
        let configuration = createAdSessionConfiguration()

        do {
            // Create ad session
            let session = try OMIDCriteoAdSession(configuration: configuration, adSessionContext: context)

            CriteoLogger.info("Session created", category: .omid)

            // Provide main ad view for measurement
            guard let adView = adView else {
                fatalError("Ad View is not initialized")
            }
            session.mainAdView = adView
            return session
        } catch {
            fatalError("Unable to instantiate ad session: \(error)")
        }

    }

    private static func createAdSessionContext(withPartner partner: OMIDCriteoPartner, adView: UIView?, vendorKey: String, verificationScriptURL: String, verificationParameters: String) -> OMIDCriteoAdSessionContext {
        do {
                
                // Create verification resource using the values provided in the ad response
                guard let verificationResource = createVerificationScriptResource(vendorKey: vendorKey,
                                                                                  verificationScriptURL: verificationScriptURL,
                                                                                  parameters: verificationParameters)
                else {
                    fatalError("Unable to instantiate session context: verification resource cannot be nil")
                }


                return try OMIDCriteoAdSessionContext(partner: partner,
                                                script: omidJSService,
                                                resources: [verificationResource],
                                                contentUrl: nil,
                                                customReferenceIdentifier: nil)
        
        } catch {
            fatalError("Unable to create ad session context: \(error)")
        }

    }


    private static func createAdSessionConfiguration() -> OMIDCriteoAdSessionConfiguration {
        do {
                return try OMIDCriteoAdSessionConfiguration(creativeType: .video,
                                                      impressionType: .beginToRender,
                                                      impressionOwner: .nativeOwner,
                                                      mediaEventsOwner: .nativeOwner,
                                                      isolateVerificationScripts: false)
        
        } catch {
            fatalError("Unable to create ad session configuration: \(error)")
        }
    }

    private func createAdEventsPublisher() {
        // Create event publisher before starting the session
        do {
            self.adEvents = try OMIDCriteoAdEvents(adSession: adSession)
        } catch {
            fatalError("Unable to instantiate OMIDAdEvents: \(error)")
        }
    }

    private func createMediaEventsPublisher() {
        do {
            self.mediaEvents = try OMIDCriteoMediaEvents(adSession: adSession)
        } catch {
            fatalError("Unable to instantiate OMIDMediaEvents: \(error)")
        }
    }


    /// Create a resource representing a verification script to be loaded in the OMID session
    /// - Parameters:
    ///   - vendorKey: Vendor identifier
    ///   - verificationScriptURL: script location
    ///   - parameters: Any parameter to be passed to the verification script.
    /// - Returns: verification script resource to be used in session creation
    private static func createVerificationScriptResource(vendorKey: String?, verificationScriptURL: String, parameters: String?) -> OMIDCriteoVerificationScriptResource? {
        guard let URL = URL(string: verificationScriptURL) else {
            fatalError("Unable to parse Verification Script URL")
        }

        if let vendorKey = vendorKey,
           let parameters = parameters,
           vendorKey.count > 0 && parameters.count > 0 {
            return OMIDCriteoVerificationScriptResource(url: URL,
                                                  vendorKey: vendorKey,
                                                  parameters: parameters)
        } else {
            return OMIDCriteoVerificationScriptResource(url: URL)
        }
    }
}

// MARK: Utility interface

extension OMIDSessionInteractor {

    func startSession() {
        CriteoLogger.info("Starting session for \(adSession.debugDescription)", category: .omid)

        createAdEventsPublisher()
        createMediaEventsPublisher()

        adSession.start()
    }

    func addMediaControlsObstruction(_ element: UIView) {
        CriteoLogger.debug("Adding button obstruction", category: .omid)
        do {
            try adSession.addFriendlyObstruction(element,
                                                 purpose: .mediaControls,
                                                 detailedReason: "Media Controls over video")
        } catch {
            fatalError("Unable to add friendly obstruction \(error.localizedDescription)")
        }
    }

    func fireAdLoaded() {
        CriteoLogger.info("Firing ad loaded", category: .omid)
        do {

            try getAdEventsPublisher().loaded()
        }
        catch {
            fatalError("OMID load error: \(error.localizedDescription)")
        }
    }

    func fireAdLoaded(vastProperties: OMIDCriteoVASTProperties) {
        CriteoLogger.info("Firing ad loaded with VAST properties", category: .omid)
        do {
            try getAdEventsPublisher().loaded(with: vastProperties)
        }
        catch {
            fatalError("OMID load error: \(error.localizedDescription)")
        }
    }

    func fireImpression() {
        CriteoLogger.info("Firing impression", category: .omid)
        do {
            try getAdEventsPublisher().impressionOccurred()
        } catch {
            fatalError("OMID impression error: \(error.localizedDescription)")
        }
    }

    func stopSession() {
        CriteoLogger.info("Stopping the session", category: .omid)
        adSession.finish()
    }

    func getMediaEventsPublisher() -> OMIDCriteoMediaEvents {
        guard let mediaEvents = self.mediaEvents else {
            fatalError("OMIDMediaEvents not instantiated, should start the session first")
        }

        return mediaEvents
    }

    func getAdEventsPublisher() -> OMIDCriteoAdEvents {
        guard let adEvents = self.adEvents else {
            fatalError("OMIDMediaEvents not instantiated, should start the session first")
        }
        return adEvents
    }

    /// The OMID SDK should be activated early on the application lifecycle
    /// - Returns: true if successful
    @discardableResult static func activateOMSDK() -> Bool {
        if OMIDCriteoSDK.shared.isActive {
            return true
        }

        // Activate the SDK
        OMIDCriteoSDK.shared.activate()

        return OMIDCriteoSDK.shared.isActive
    }

    //    For the simplicity of the demo project the javascript OMID SDK is embedded in the application bundle
    //    in a real life scenario the javascript file should be hosted in a remote server
    static func prefetchOMIDSDK() {
        CriteoLogger.info("Simulating OMID SDK Javascript download ...", category: .omid)
    }

    static var omidJSService: String {
        let omidServiceUrl = Bundle.main.url(forResource: "omsdk-v1", withExtension: "js")!
        return try! String(contentsOf: omidServiceUrl)
    }
}

#endif
