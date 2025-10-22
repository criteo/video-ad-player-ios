//
//  Logger.swift
//  OM-Demo
//
//  Created by Serxhio Gugo on 8/12/25.
//  Copyright © 2025 Open Measurement Working Group. All rights reserved.
//

/*
Logging System for OM-Demo
 
 BASIC USAGE:
 Logger.info("User tapped play button", category: .ui)
 Logger.error("Network request failed", category: .network)
 Logger.debug("Parsing VAST element", category: .vast)
 
 SPECIALIZED METHODS:
 Logger.beacon("Impression fired", url: impressionURL, success: true)
 Logger.network("VAST fetched", url: vastURL, statusCode: 200)
 Logger.video("Playback started", currentTime: 0.0, duration: 30.0)
 
 CATEGORY CONTROL EXAMPLES:
 
 // Enable only specific categories
 Logger.enableOnly(.beacon)                    // Only beacon logs
 Logger.enableOnly(.network, .vast)            // Network + VAST parsing
 Logger.enableOnly(.video, .ui)                // Video playback + UI
 
 // Disable noisy categories
 Logger.disable(.vast)                         // Hide VAST parsing details
 Logger.disable(.vast, .omid)                  // Hide verbose categories
 
 // Enable all (default)
 Logger.enableAll()
 
 COMMON DEBUGGING SCENARIOS:
 
 // Debug beacon issues only
 Logger.enableOnly(.beacon)
 
 // Debug network problems
 Logger.enableOnly(.network, .vast)
 
 // Debug video playback
 Logger.enableOnly(.video, .ui)
 
 // Production mode (errors/warnings only)
 Logger.configureForProduction()
 Logger.disable(.vast, .omid)
 
 // Development mode (everything)
 Logger.configureForDevelopment()
 Logger.enableAll()
 
 CATEGORIES:
 .general  - General app logs
 .network  - Network requests, downloads
 .beacon   - Beacon firing, retries
 .video    - Video playback, closed captions
 .vast     - VAST XML parsing
 .omid     - OMID SDK integration  
 .ui       - User interactions
 */

import Foundation
import os.log

/// Logging system for OM-Demo
final class CriteoLogger {
    
    /// Log levels with priority ordering
    enum Level: Int, CaseIterable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
        
        var name: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            case .critical: return "CRITICAL"
            }
        }
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }
    
    /// Log categories for different subsystems
    enum Category: String, CaseIterable {
        case general = "General"
        case network = "Network"
        case beacon = "Beacon"
        case video = "Video"
        case vast = "VAST"
        case omid = "OMID"
        case ui = "UI"
        
        var osLog: OSLog {
            return OSLog(subsystem: "com.omid.demo", category: self.rawValue)
        }
    }
    
    // MARK: - Configuration
    
    /// Minimum log level to display (configurable)
    static var minimumLevel: Level = .debug
    
    /// Whether to use system logging (Console.app) in addition to print
    static var useSystemLogging: Bool = true
    
    /// Whether to include timestamps in console output
    static var includeTimestamp: Bool = true
    
    /// Whether to include file/function info in console output
    static var includeLocation: Bool = false
    
    /// Categories that are enabled for logging (empty set means all categories are enabled)
    static var enabledCategories: Set<Category> = []
    
    /// Categories that are explicitly disabled (takes precedence over enabledCategories)
    static var disabledCategories: Set<Category> = []
    
    // MARK: - Public Logging Methods
    
    /// Log a debug message
    static func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log an info message
    static func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    static func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log an error message
    static func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log a critical message
    static func critical(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .critical, message: message, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Specialized Logging Methods
    
    /// Log network request/response
    static func network(_ message: String, url: URL? = nil, statusCode: Int? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var logMessage = message
        if let url = url {
            logMessage += " | URL: \(url.absoluteString)"
        }
        if let statusCode = statusCode {
            logMessage += " | Status: \(statusCode)"
        }
        log(level: .info, message: logMessage, category: .network, file: file, function: function, line: line)
    }
    
    /// Log beacon firing with result
    static func beacon(_ message: String, url: URL? = nil, success: Bool? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var logMessage = message
        if let url = url {
            logMessage += " | \(url.absoluteString)"
        }
        
        let level: Level = success == false ? .warning : .info
        log(level: level, message: logMessage, category: .beacon, file: file, function: function, line: line)
    }
    
    /// Log video playback events
    static func video(_ message: String, currentTime: Double? = nil, duration: Double? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var logMessage = message
        if let currentTime = currentTime, let duration = duration {
            logMessage += " | \(String(format: "%.1f", currentTime))/\(String(format: "%.1f", duration))s"
        }
        log(level: .info, message: logMessage, category: .video, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging Implementation
    
    private static func log(level: Level, message: String, category: Category, file: String, function: String, line: Int) {
        // Check if we should log this level
        guard level.rawValue >= minimumLevel.rawValue else { return }
        
        // Check if this category is enabled
        guard isCategoryEnabled(category) else { return }
        
        // Format the message
        let formattedMessage = formatMessage(level: level, message: message, category: category, file: file, function: function, line: line)
        
        // Console output
        print(formattedMessage)
        
        // System logging (Console.app)
//        if useSystemLogging {
//            os_log("%{public}@", log: category.osLog, type: level.osLogType, message)
//        }
    }
    
    /// Checks if a category is enabled for logging
    private static func isCategoryEnabled(_ category: Category) -> Bool {
        // If explicitly disabled, don't log
        if disabledCategories.contains(category) {
            return false
        }
        
        // If no specific categories are enabled, all are enabled by default
        if enabledCategories.isEmpty {
            return true
        }
        
        // Only log if category is in the enabled set
        return enabledCategories.contains(category)
    }
    
    private static func formatMessage(level: Level, message: String, category: Category, file: String, function: String, line: Int) -> String {
        var components: [String] = []
        
        // Timestamp
        if includeTimestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            components.append(formatter.string(from: Date()))
        }
        
        // Level and category
        components.append("\(level.emoji) [\(level.name)]")
        components.append("[\(category.rawValue)]")
        
        // Location info
        if includeLocation {
            let filename = (file as NSString).lastPathComponent
            components.append("[\(filename):\(line) \(function)]")
        }
        
        // Message
        components.append(message)
        
        return components.joined(separator: " ")
    }
}

// MARK: - Configuration Extensions

extension CriteoLogger {
    /// Configure logger for development
    static func configureForDevelopment() {
        minimumLevel = .debug
        useSystemLogging = true
        includeTimestamp = true
        includeLocation = false
        enabledCategories = []  // All categories enabled
        disabledCategories = []
    }
    
    /// Configure logger for production
    static func configureForProduction() {
        minimumLevel = .warning
        useSystemLogging = true
        includeTimestamp = false
        includeLocation = false
        enabledCategories = []  // All categories enabled
        disabledCategories = []
    }
    
    /// Configure logger for testing
    static func configureForTesting() {
        minimumLevel = .info
        useSystemLogging = false
        includeTimestamp = false
        includeLocation = true
        enabledCategories = []  // All categories enabled
        disabledCategories = []
    }
    
    // MARK: - Category Management
    
    /// Enable logging for specific categories only
    static func enableOnly(_ categories: Category...) {
        enabledCategories = Set(categories)
        disabledCategories = []
    }
    
    /// Enable logging for specific categories only
    static func enableOnly(_ categories: [Category]) {
        enabledCategories = Set(categories)
        disabledCategories = []
    }
    
    /// Disable logging for specific categories
    static func disable(_ categories: Category...) {
        disabledCategories = Set(categories)
    }
    
    /// Disable logging for specific categories
    static func disable(_ categories: [Category]) {
        disabledCategories = Set(categories)
    }
    
    /// Enable all categories (default behavior)
    static func enableAll() {
        enabledCategories = []
        disabledCategories = []
    }
    
    /// Check if a specific category is currently enabled
    static func isEnabled(_ category: Category) -> Bool {
        return isCategoryEnabled(category)
    }
    
    /// Get list of currently enabled categories
    static func getEnabledCategories() -> Set<Category> {
        if enabledCategories.isEmpty && disabledCategories.isEmpty {
            return Set(Category.allCases) // All enabled
        } else if enabledCategories.isEmpty {
            return Set(Category.allCases.filter { !disabledCategories.contains($0) })
        } else {
            return enabledCategories.subtracting(disabledCategories)
        }
    }
}
