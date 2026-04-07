//
//  CmuxTreeParser.swift
//  ClaudeIsland
//
//  Parses the output of `cmux tree --all` to build a complete map of
//  windows → workspaces → panes → surfaces, including TTY assignments.
//
//  This is a standalone file — no existing files are modified.
//

import Foundation

/// A location within cmux's hierarchy.
struct CmuxLocation: Sendable {
    let windowRef: String      // e.g., "window:1"
    let workspaceRef: String   // e.g., "workspace:2"
    let paneRef: String        // e.g., "pane:8"
    let surfaceRef: String     // e.g., "surface:14"
    let title: String          // e.g., "zhangzy@dgx-127: ~"
    let tty: String?           // e.g., "ttys008"
}

/// Parses `cmux tree --all` output into structured CmuxLocation entries.
enum CmuxTreeParser {

    /// Parse the full tree output and return all surfaces.
    static func parse(_ treeOutput: String) -> [CmuxLocation] {
        var results: [CmuxLocation] = []
        var currentWindow: String?
        var currentWorkspace: String?
        var currentPane: String?

        for line in treeOutput.components(separatedBy: "\n") {
            // Match window line: "window window:1 [current] ◀ active"
            if let windowRef = extractRef(from: line, prefix: "window ") {
                currentWindow = windowRef
                continue
            }

            // Match workspace line: "workspace workspace:2 \"dgx127\" [selected]"
            if let workspaceRef = extractRef(from: line, prefix: "workspace ") {
                currentWorkspace = workspaceRef
                continue
            }

            // Match pane line: "pane pane:8 [focused]"
            if let paneRef = extractRef(from: line, prefix: "pane ") {
                currentPane = paneRef
                continue
            }

            // Match surface line: "surface surface:14 [terminal] \"title\" tty=ttys008"
            if let surfaceRef = extractRef(from: line, prefix: "surface ") {
                guard let window = currentWindow,
                      let workspace = currentWorkspace,
                      let pane = currentPane else { continue }

                let title = extractQuotedTitle(from: line) ?? ""
                let tty = extractTTY(from: line)

                results.append(CmuxLocation(
                    windowRef: window,
                    workspaceRef: workspace,
                    paneRef: pane,
                    surfaceRef: surfaceRef,
                    title: title,
                    tty: tty
                ))
                continue
            }
        }

        return results
    }

    /// Find surfaces matching a given TTY device (e.g., "ttys008").
    static func findByTTY(_ tty: String, in surfaces: [CmuxLocation]) -> [CmuxLocation] {
        let normalizedTTY = tty.replacingOccurrences(of: "/dev/", with: "")
        return surfaces.filter { surface in
            guard let surfaceTTY = surface.tty else { return false }
            return surfaceTTY == normalizedTTY
        }
    }

    /// Disambiguate multiple TTY matches by checking if the title contains the hostname.
    static func disambiguateByHost(
        _ candidates: [CmuxLocation],
        host: String,
        sshAlias: String? = nil
    ) -> CmuxLocation? {
        // Prefer title match
        for candidate in candidates {
            if candidate.title.localizedCaseInsensitiveContains(host) {
                return candidate
            }
            if let alias = sshAlias, candidate.title.localizedCaseInsensitiveContains(alias) {
                return candidate
            }
        }
        // Fallback: first candidate
        return candidates.first
    }

    // MARK: - Private helpers

    private static func extractRef(from line: String, prefix: String) -> String? {
        guard let range = line.range(of: prefix) else { return nil }
        let afterPrefix = line[range.upperBound...]
        let tokens = afterPrefix.split(separator: " ", maxSplits: 1)
        guard let ref = tokens.first else { return nil }
        let refStr = String(ref)
        guard refStr.contains(":") else { return nil }
        return refStr
    }

    private static func extractQuotedTitle(from line: String) -> String? {
        guard let firstQuote = line.firstIndex(of: "\"") else { return nil }
        let afterFirst = line.index(after: firstQuote)
        guard afterFirst < line.endIndex,
              let secondQuote = line[afterFirst...].firstIndex(of: "\"") else { return nil }
        return String(line[afterFirst..<secondQuote])
    }

    private static func extractTTY(from line: String) -> String? {
        guard let range = line.range(of: "tty=") else { return nil }
        let afterTTY = line[range.upperBound...]
        let tty = afterTTY.trimmingCharacters(in: .whitespacesAndNewlines)
        return tty.isEmpty ? nil : tty
    }
}
