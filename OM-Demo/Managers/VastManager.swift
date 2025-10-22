//
//  VastManager.swift
//  OM-Demo
//
//  Created by Serxhio Gugo on 6/13/25.
//  Copyright © 2025 Open Measurement Working Group. All rights reserved.
//

import Foundation

/// Represents elements found in VAST format
private enum VastElementType: String {
    case impression = "Impression"
    case error = "Error"
    case duration = "Duration"
    case mediaFile = "MediaFile"
    case tracking = "Tracking"
    case clickTracking = "ClickTracking"
    case clickThrough = "ClickThrough"
    case closedCaptionFile = "ClosedCaptionFile"
    case javascriptResource = "JavaScriptResource"
    case verificationParameters = "VerificationParameters"
    case verification = "Verification"
}
/// Modeled after the VAST format
public struct VASTAd {
    /// The URL of the main video creative (typically .mp4)
    public var videoURL: URL?
    
    /// All available media files (renditions)
    public var mediaFiles: [VASTMediaFile] = []
    
    /// The duration string, e.g. "00:00:30.020"
    public var duration: String?
    
    /// All impression beacon URLs
    public var impressionURLs: [URL] = []
    
    /// All error beacon URLs
    public var errorURLs: [URL] = []
    
    /// Tracking events (e.g. "start", "firstQuartile", etc.) mapped to their beacon URLs
    public var trackingEvents: [String: URL] = [:]
    
    /// Any click‐tracking beacon URLs
    public var clickTrackingURLs: [URL] = []
    
    /// The “ClickThrough” URL (where user should go when tapping the ad)
    public var clickThroughURL: URL?
    
    /// URL of the closed‐caption file (e.g. WebVTT)
    public var closedCaptionURL: URL?
    
    /// The OMID verification script URL
    public var verificationScriptURL: URL?
    
    /// JSON or string parameters for the OMID verification
    public var verificationParameters: String?
    
    /// Tracking events inside the <AdVerifications> block
    public var verificationTracking: [String: URL] = [:]
    
    /// Vendor identifier (pulled from the <Verification vendor="…"> attribute)
    public var vendorKey: String?
}

/// A single media file rendition from VAST
public struct VASTMediaFile {
    public var url: URL
    public var width: Int?
    public var height: Int?
    public var type: String?
    public var captionURL: URL?
}

public final class VASTManager: NSObject, XMLParserDelegate {
    private var ad = VASTAd()
    private var currentElement = ""
    private var currentTrackingEvent: String?
    private var foundCharacters = ""
    private var isInVerification = false
    private var isInMediaFile = false
    private var isInCaptionFile = false
    private var currentMediaAttributes: (width: Int?, height: Int?, type: String?) = (nil, nil, nil)
    private var currentMediaURLBuffer: String = ""
    private var currentCaptionURLBuffer: String = ""

    /// Parses raw VAST XML data into a VASTAd model.
    public func parseVAST(data: Data) -> VASTAd {
        CriteoLogger.debug("Starting VAST XML parsing, data size: \(data.count) bytes", category: .vast)
        let parser = XMLParser(data: data)
        parser.delegate = self
        let success = parser.parse()
        
        if success {
            CriteoLogger.debug("VAST XML parsing completed successfully", category: .vast)
        } else if let error = parser.parserError {
            CriteoLogger.error("VAST XML parsing failed: \(error.localizedDescription)", category: .vast)
        }
        
        return ad
    }

    // Reset state before parsing a new document
    public func parserDidStartDocument(_ parser: XMLParser) {
        CriteoLogger.debug("VAST XML parser started", category: .vast)
        ad = VASTAd()
        currentElement = ""
        currentTrackingEvent = nil
        foundCharacters = ""
        isInVerification = false
        isInMediaFile = false
        isInCaptionFile = false
        currentMediaAttributes = (nil, nil, nil)
        currentMediaURLBuffer = ""
        currentCaptionURLBuffer = ""
    }

    // Called when an element starts
    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributesDict: [String: String] = [:]) {
        currentElement  = elementName
        foundCharacters = ""

        if elementName == VastElementType.tracking.rawValue,
           let event = attributesDict["event"] {
            currentTrackingEvent = event
        }

        if elementName == VastElementType.verification.rawValue {
            isInVerification = true
            if let vendor = attributesDict["vendor"] {
                ad.vendorKey = vendor
            }
        }

        if elementName == VastElementType.mediaFile.rawValue {
            isInMediaFile = true
            // Capture basic attributes
            let w = Int(attributesDict["width"] ?? "")
            let h = Int(attributesDict["height"] ?? "")
            let t = attributesDict["type"]
            currentMediaAttributes = (w, h, t)
            currentMediaURLBuffer = ""
            currentCaptionURLBuffer = ""
        }

        if isInMediaFile && elementName == VastElementType.closedCaptionFile.rawValue {
            isInCaptionFile = true
            currentCaptionURLBuffer = ""
        }
    }

    // Called when characters are found inside an element
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        foundCharacters += string
        // Accumulate media URL text only when directly inside <MediaFile>
        if isInMediaFile && !isInCaptionFile && currentElement == VastElementType.mediaFile.rawValue {
            currentMediaURLBuffer += string
        }
        // Accumulate caption URL when inside <ClosedCaptionFile>
        if isInMediaFile && isInCaptionFile && currentElement == VastElementType.closedCaptionFile.rawValue {
            currentCaptionURLBuffer += string
        }
    }

    // Called when an element ends
    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {
        guard let type = VastElementType(rawValue: elementName) else {
            foundCharacters = ""
            return
        }
        let value = foundCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
        switch type {
        case .impression:
            if let url = URL(string: value) {
                ad.impressionURLs.append(url)
                CriteoLogger.debug("Found impression URL", category: .vast)
            }
        case .error:
            if let url = URL(string: value) {
                ad.errorURLs.append(url)
                CriteoLogger.debug("Found error URL", category: .vast)
            }
        case .duration:
            ad.duration = value
            CriteoLogger.debug("Found duration: \(value)", category: .vast)
        case .mediaFile:
            // Finalize current media file with accumulated URL and optional caption
            let mediaURLString = currentMediaURLBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: mediaURLString) {
                let media = VASTMediaFile(url: url,
                                          width: currentMediaAttributes.width,
                                          height: currentMediaAttributes.height,
                                          type: currentMediaAttributes.type,
                                          captionURL: URL(string: currentCaptionURLBuffer.trimmingCharacters(in: .whitespacesAndNewlines)))
                ad.mediaFiles.append(media)
                // Back-compat: set primary videoURL if not set yet (prefer first mp4)
                if ad.videoURL == nil {
                    ad.videoURL = url
                }
                CriteoLogger.debug("Found media file URL: \(url.absoluteString)", category: .vast)
            }
            // Reset media state
            isInMediaFile = false
            isInCaptionFile = false
            currentMediaAttributes = (nil, nil, nil)
            currentMediaURLBuffer = ""
            currentCaptionURLBuffer = ""
        case .tracking:
            if let event = currentTrackingEvent,
               let url   = URL(string: value) {
                if isInVerification {
                    ad.verificationTracking[event] = url
                    CriteoLogger.debug("Found verification tracking event: \(event)", category: .vast)
                } else {
                    ad.trackingEvents[event] = url
                    CriteoLogger.debug("Found tracking event: \(event)", category: .vast)
                }
            }
            currentTrackingEvent = nil
        case .clickTracking:
            if let url = URL(string: value) {
                ad.clickTrackingURLs.append(url)
                CriteoLogger.debug("Found click tracking URL", category: .vast)
            }
        case .clickThrough:
            if let url = URL(string: value) {
                ad.clickThroughURL = url
                CriteoLogger.debug("Found click-through URL: \(url.absoluteString)", category: .vast)
            }
        case .closedCaptionFile:
            if isInMediaFile {
                // handled via buffer, but ensure value fallback
                if currentCaptionURLBuffer.isEmpty {
                    currentCaptionURLBuffer = value
                }
                isInCaptionFile = false
            } else {
                if let url = URL(string: value) {
                    ad.closedCaptionURL = url
                    CriteoLogger.debug("Found closed caption URL: \(url.absoluteString)", category: .vast)
                }
            }
        case .javascriptResource:
            if isInVerification, let url = URL(string: value) {
                ad.verificationScriptURL = url
                CriteoLogger.debug("Found verification script URL", category: .vast)
            }
        case .verificationParameters:
            if isInVerification {
                ad.verificationParameters = value
                CriteoLogger.debug("Found verification parameters", category: .vast)
            }
        case .verification:
            isInVerification = false
            CriteoLogger.debug("Exiting verification block", category: .vast)
        }

        foundCharacters = ""
    }
}
