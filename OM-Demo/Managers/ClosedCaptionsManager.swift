//
//  ClosedCaptionManager.swift
//  OM-Demo
//
//  Created by Serxhio Gugo on 7/15/25.
//  Copyright © 2025 Open Measurement Working Group. All rights reserved.
//

import Foundation
import CoreMedia

/// A single WebVTT cue
struct ClosedCaptionsCue {
    let start: TimeInterval
    let end:   TimeInterval
    let text:  String
}

/// Loads a `.vtt` file and handles timing
final class ClosedCaptionsManager {
    private(set) var cues: [ClosedCaptionsCue] = []

    /// Load and parse a side-car WebVTT file.
    func load(from vttURL: URL) throws {
        CriteoLogger.debug("Loading closed captions file", category: .video)
        
        do {
            let raw = try String(contentsOf: vttURL)
            let blocks = raw.components(separatedBy: "\n\n")
            var parsed: [ClosedCaptionsCue] = []

            for block in blocks {
                let lines = block
                    .split(whereSeparator: \.isNewline)
                    .map(String.init)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard lines.count >= 2 else { continue }

                let timing = lines[0].components(separatedBy: " --> ")
                guard timing.count == 2,
                      let s = ClosedCaptionsManager.parseTS(timing[0]),
                      let e = ClosedCaptionsManager.parseTS(timing[1]) else {
                    continue
                }

                let text = lines[1...].joined(separator: "\n")
                parsed.append(.init(start: s, end: e, text: text))
            }

            cues = parsed.sorted { $0.start < $1.start }
            CriteoLogger.info("Closed captions loaded: \(cues.count) cues", category: .video)
            
        } catch {
            CriteoLogger.error("Failed to load closed captions: \(error.localizedDescription)", category: .video)
            throw error
        }
    }

    /// Returns the closed captions text for a given playback time (or nil).
    func text(at time: CMTime) -> String? {
        let t = time.seconds
        guard !cues.isEmpty else { return nil }

        // find the first cue whose start > t
        var low = 0, high = cues.count
        while low < high {
            let mid = (low + high) / 2
            if cues[mid].start > t {
                high = mid
            } else {
                low = mid + 1
            }
        }

        // low is now the insertion index: the first cue with start > t
        let index = low - 1
        guard index >= 0 else { return nil }

        let cue = cues[index]
        return (t <= cue.end) ? cue.text : nil
    }

    // MARK: – Helpers

    private static func parseTS(_ ts: String) -> TimeInterval? {
        // e.g. "00:00:04.099"
        let comps = ts
            .replacingOccurrences(of: ",", with: ".")
            .split(separator: ":")
            .map(String.init)
        guard comps.count == 3,
              let h = Double(comps[0]),
              let m = Double(comps[1]),
              let s = Double(comps[2]) else {
            return nil
        }
        return h * 3600 + m * 60 + s
    }
}
