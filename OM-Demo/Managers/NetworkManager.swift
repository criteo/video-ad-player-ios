//
//  NetworkManager.swift
//  OM-Demo
//
//  Created by Serxhio Gugo on 7/7/25.
//  Copyright © 2025 Open Measurement Working Group. All rights reserved.
//

import Foundation

public class NetworkManager {
    public static let shared = NetworkManager()
    private init() {}

    /// Asynchronously fetches VAST XML from `remoteURL`, parses it off the main thread,
    /// and returns a fully-populated `VASTAd`. Cancelling the enclosing Task will
    /// automatically cancel the URLSession request.
    public func fetchAndParseVAST(from remoteURL: URL) async throws -> VASTAd {
        CriteoLogger.debug("Fetching VAST XML", category: .network)
        
        do {
            // 1) Fetch the raw XML data. This call is cancellation-aware.
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            
            CriteoLogger.network("VAST XML fetched", 
                          url: remoteURL, 
                          statusCode: statusCode)

            // 2) Parse off the main actor so UI isn't blocked.
            let ad = await Task.detached(priority: .userInitiated) {
                return VASTManager().parseVAST(data: data)
            }.value
            
            // Log parsed ad details
            logParsedAdDetails(ad)
            
            return ad
            
        } catch {
            CriteoLogger.error("VAST fetch failed: \(error.localizedDescription)", category: .network)
            throw error
        }
    }

    /// Parses VAST from a raw XML string off the main thread and returns a `VASTAd`.
    /// This does not perform any network requests.
    public func parseVAST(fromXML xmlString: String) async -> VASTAd {
        let data = Data(xmlString.utf8)
        let ad = await Task.detached(priority: .userInitiated) {
            return VASTManager().parseVAST(data: data)
        }.value
        logParsedAdDetails(ad)
        return ad
    }
    
    /// Logs details about the parsed VAST ad
    private func logParsedAdDetails(_ ad: VASTAd) {
        var details: [String] = []
        
        if ad.videoURL != nil { details.append("video") }
        if ad.closedCaptionURL != nil { details.append("captions") }
        if !ad.impressionURLs.isEmpty { details.append("\(ad.impressionURLs.count) impressions") }
        if !ad.clickTrackingURLs.isEmpty { details.append("\(ad.clickTrackingURLs.count) click trackers") }
        if !ad.trackingEvents.isEmpty { details.append("\(ad.trackingEvents.count) tracking events") }
        if ad.verificationScriptURL != nil { details.append("OMID verification") }
        
        let summary = details.isEmpty ? "empty ad" : details.joined(separator: ", ")
        CriteoLogger.info("VAST ad parsed: \(summary)", category: .vast)
    }
}

