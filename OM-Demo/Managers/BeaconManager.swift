//
//  BeaconManager.swift
//  OM-Demo
//
//  Created by Serxhio Gugo on 8/12/25.
//  Copyright © 2025 Open Measurement Working Group. All rights reserved.
//

import Foundation

/// Manages beacon firing with retry logic, error handling, and task cancellation
@MainActor
final class BeaconManager {
    
    /// Active beacon tasks for cancellation
    private var beaconTasks: Set<Task<Void, Never>> = []
    
    /// Fires a beacon to a specific URL with retry logic and proper error handling
    func fireBeacon(url: URL, type: String) {
        let task = Task {
            await self.fireBeaconWithRetry(url: url, type: type, attempt: 1)
        }
        
        // Store task for potential cancellation
        beaconTasks.insert(task)
        
        // Handle cleanup when task completes
        Task { @MainActor [weak self] in
            _ = await task.value // Wait for the beacon task to complete
            self?.beaconTasks.remove(task)
        }
    }
    
    /// Fires all impression beacons from a VAST ad
    func fireImpressionBeacons(from ad: VASTAd) {
        for impressionURL in ad.impressionURLs {
            fireBeacon(url: impressionURL, type: "impression")
        }
    }
    
    /// Fires all click tracking beacons from a VAST ad
    func fireClickTrackingBeacons(from ad: VASTAd) {
        for clickTrackingURL in ad.clickTrackingURLs {
            fireBeacon(url: clickTrackingURL, type: "clickTracking")
        }
    }
    
    /// Fires a single beacon URL with a specific type name
    func fireBeacon(url: URL?, type: String) {
        guard let url = url else {
            CriteoLogger.warning("No beacon URL found for type: \(type)", category: .beacon)
            return
        }
        fireBeacon(url: url, type: type)
    }
    
    /// Cancels all active beacon tasks
    func cancelAllBeacons() {
        let taskCount = beaconTasks.count
        for beaconTask in beaconTasks {
            beaconTask.cancel()
        }
        beaconTasks.removeAll()
        CriteoLogger.info("Cancelled \(taskCount) beacon tasks", category: .beacon)
    }
    
    // MARK: - Private Methods
    
    /// Fires a beacon with retry logic and exponential backoff
    private func fireBeaconWithRetry(url: URL, type: String, attempt: Int, maxAttempts: Int = 3) async {
        // Check for cancellation
        guard !Task.isCancelled else {
            CriteoLogger.debug("\(type) beacon cancelled", category: .beacon)
            return
        }
        
        CriteoLogger.debug("Firing \(type) beacon (attempt \(attempt)/\(maxAttempts))", category: .beacon)
        
        do {
            // Create request with timeout
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0 // 10 second timeout
            request.httpMethod = "GET"
            request.setValue("OM-Demo/1.0", forHTTPHeaderField: "User-Agent")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            // Check for cancellation after network call
            guard !Task.isCancelled else {
                CriteoLogger.debug("\(type) beacon cancelled after network call", category: .beacon)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    CriteoLogger.beacon("\(type) beacon succeeded", url: url, success: true)
                } else {
                    CriteoLogger.beacon("\(type) beacon returned status \(httpResponse.statusCode)", url: url, success: false)
                    
                    // Retry on server errors (5xx) or specific client errors
                    if shouldRetryForStatusCode(httpResponse.statusCode) && attempt < maxAttempts {
                        await retryAfterDelay(url: url, type: type, attempt: attempt + 1, maxAttempts: maxAttempts)
                    } else {
                        CriteoLogger.error("\(type) beacon failed permanently with status: \(httpResponse.statusCode)", category: .beacon)
                    }
                }
            }
        } catch is CancellationError {
            CriteoLogger.debug("\(type) beacon cancelled during network request", category: .beacon)
        } catch {
            CriteoLogger.warning("\(type) beacon failed: \(error.localizedDescription)", category: .beacon)
            
            // Don't retry if cancelled
            guard !Task.isCancelled else { return }
            
            // Retry on network errors
            if shouldRetryForError(error) && attempt < maxAttempts {
                await retryAfterDelay(url: url, type: type, attempt: attempt + 1, maxAttempts: maxAttempts)
            } else {
                CriteoLogger.error("\(type) beacon failed permanently after \(attempt) attempts", category: .beacon)
            }
        }
    }
    
    /// Determines if we should retry based on HTTP status code
    private func shouldRetryForStatusCode(_ statusCode: Int) -> Bool {
        // Retry on server errors (5xx) and some client errors
        return statusCode >= 500 || statusCode == 408 || statusCode == 429
    }
    
    /// Determines if we should retry based on error type
    private func shouldRetryForError(_ error: Error) -> Bool {
        // Retry on network connectivity issues, timeouts, etc.
        let nsError = error as NSError
        
        // URLError codes that indicate retryable conditions
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    /// Waits for exponential backoff delay then retries
    private func retryAfterDelay(url: URL, type: String, attempt: Int, maxAttempts: Int) async {
        // Check for cancellation before delay
        guard !Task.isCancelled else { return }
        
        // Exponential backoff: 1s, 2s, 4s
        let delay = pow(2.0, Double(attempt - 1))
        CriteoLogger.debug("Retrying \(type) beacon in \(String(format: "%.1f", delay))s...", category: .beacon)
        
        do {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } catch is CancellationError {
            CriteoLogger.debug("\(type) beacon retry cancelled during delay", category: .beacon)
            return
        } catch {
            // Unexpected error during sleep, but continue
        }
        
        await fireBeaconWithRetry(url: url, type: type, attempt: attempt, maxAttempts: maxAttempts)
    }
}
