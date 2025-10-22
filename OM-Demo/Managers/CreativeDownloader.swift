//
//  CreativeDownloader.swift
//  OM-Demo
//
//  Created by Julien AMAR on 10/2/24.
//  Copyright © 2024 Open Measurement Working Group. All rights reserved.
//

import Foundation

/// Asynchronously downloads a creative (video or caption) and renames it with the proper extension.
public final class CreativeDownloaderAsync {
    /// Downloads the resource at `remoteURL` and moves it into a temporary file
    /// with the same file extension as `remoteURL`.
    /// - Parameter remoteURL: URL of the remote resource (e.g., .mp4 or .vtt)
    /// - Returns: Local file URL with the correct extension
    /// - Throws: An error if the download or file move fails
    ///
    public func fetchCreative(from remoteURL: URL) async throws -> URL {
        let fileType = remoteURL.pathExtension.uppercased()
        CriteoLogger.info("Downloading \(fileType) creative", category: .network)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // 1. Download to a system-provided temporary location
            let (tempLocation, response) = try await URLSession.shared.download(from: remoteURL)
            
            let downloadTime = CFAbsoluteTimeGetCurrent() - startTime
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            
            // Get file size
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: tempLocation.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            
            CriteoLogger.network("\(fileType) creative downloaded", 
                          url: remoteURL, 
                          statusCode: statusCode)
            CriteoLogger.debug("\(fileType) download completed in \(String(format: "%.2f", downloadTime))s, size: \(fileSize) bytes", 
                        category: .network)

            // 2. Extract the original file extension
            let fileExtension = remoteURL.pathExtension

            // 3. Create a new destination URL in the temp directory with that extension
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            // 4. Move the downloaded file to the destination URL
            try FileManager.default.moveItem(at: tempLocation, to: destinationURL)
            
            CriteoLogger.debug("\(fileType) creative saved to: \(destinationURL.lastPathComponent)", category: .network)
            
            return destinationURL
            
        } catch {
            let downloadTime = CFAbsoluteTimeGetCurrent() - startTime
            CriteoLogger.error("\(fileType) creative download failed after \(String(format: "%.2f", downloadTime))s: \(error.localizedDescription)", 
                        category: .network)
            throw error
        }
    }
}
