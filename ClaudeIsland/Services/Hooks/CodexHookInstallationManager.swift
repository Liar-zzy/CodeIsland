//
//  CodexHookInstallationManager.swift
//  ClaudeIsland
//
//  Manages installing/uninstalling Code Island as a Codex hook provider.
//  Writes to ~/.codex/config.toml (feature flag) and ~/.codex/hooks.json (hook entries).
//

import Foundation

struct CodexHookInstallationStatus: Equatable, Sendable {
    var codexDirectory: URL
    var configURL: URL
    var hooksURL: URL
    var manifestURL: URL
    /// Path to the hook script/binary that was installed, if known.
    var hookScriptPath: String?
    var featureFlagEnabled: Bool
    var managedHooksPresent: Bool
    var manifest: CodexHookInstallerManifest?
}

/// Manages the full lifecycle of Code Island's Codex hook installation.
///
/// Usage:
///   let manager = CodexHookInstallationManager()
///   try manager.install(hookScriptPath: "/path/to/codeisland-state.py")
///   try manager.uninstall()
final class CodexHookInstallationManager: @unchecked Sendable {
    let codexDirectory: URL
    private let fileManager: FileManager

    init(
        codexDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.codexDirectory = codexDirectory
        self.fileManager = fileManager
    }

    func status(hookScriptPath: String? = nil) throws -> CodexHookInstallationStatus {
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let hooksURL = codexDirectory.appendingPathComponent("hooks.json")
        let manifestURL = resolvedManifestURL()

        let configContents = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let hooksData = try? Data(contentsOf: hooksURL)
        let manifest = try loadManifest(at: manifestURL)
        let managedCommand = manifest?.hookCommand
            ?? hookScriptPath.map { CodexHookInstaller.hookCommand(for: $0) }
        let managedHooksPresent = ((try? CodexHookInstaller.uninstallHooksJSON(
            existingData: hooksData,
            managedCommand: managedCommand
        ))?.changed) == true

        return CodexHookInstallationStatus(
            codexDirectory: codexDirectory,
            configURL: configURL,
            hooksURL: hooksURL,
            manifestURL: manifestURL,
            hookScriptPath: hookScriptPath,
            featureFlagEnabled: configContents.contains("codex_hooks = true"),
            managedHooksPresent: managedHooksPresent,
            manifest: manifest
        )
    }

    @discardableResult
    func install(hookScriptPath: String) throws -> CodexHookInstallationStatus {
        try fileManager.createDirectory(at: codexDirectory, withIntermediateDirectories: true)

        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let hooksURL = codexDirectory.appendingPathComponent("hooks.json")
        let manifestURL = codexDirectory.appendingPathComponent(CodexHookInstallerManifest.fileName)
        let legacyManifestURL = codexDirectory.appendingPathComponent(CodexHookInstallerManifest.legacyFileName)

        let existingConfig = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let existingHooks = try? Data(contentsOf: hooksURL)

        let command = CodexHookInstaller.hookCommand(for: hookScriptPath)
        let featureMutation = CodexHookInstaller.enableCodexHooksFeature(in: existingConfig)
        let hooksMutation = try CodexHookInstaller.installHooksJSON(existingData: existingHooks, hookCommand: command)

        if featureMutation.changed, fileManager.fileExists(atPath: configURL.path) {
            try backupFile(at: configURL)
        }
        if hooksMutation.changed, fileManager.fileExists(atPath: hooksURL.path) {
            try backupFile(at: hooksURL)
        }

        try featureMutation.contents.write(to: configURL, atomically: true, encoding: .utf8)
        if let hooksData = hooksMutation.contents {
            try hooksData.write(to: hooksURL, options: .atomic)
        }

        let manifest = CodexHookInstallerManifest(
            hookCommand: command,
            enabledCodexHooksFeature: featureMutation.featureEnabledByInstaller
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

        if fileManager.fileExists(atPath: legacyManifestURL.path) {
            try fileManager.removeItem(at: legacyManifestURL)
        }

        return try status(hookScriptPath: hookScriptPath)
    }

    @discardableResult
    func uninstall() throws -> CodexHookInstallationStatus {
        let configURL = codexDirectory.appendingPathComponent("config.toml")
        let hooksURL = codexDirectory.appendingPathComponent("hooks.json")
        let manifestURL = resolvedManifestURL()
        let primaryManifestURL = codexDirectory.appendingPathComponent(CodexHookInstallerManifest.fileName)
        let legacyManifestURL = codexDirectory.appendingPathComponent(CodexHookInstallerManifest.legacyFileName)

        let manifest = try loadManifest(at: manifestURL)
        let existingHooks = try? Data(contentsOf: hooksURL)
        let hooksMutation = try CodexHookInstaller.uninstallHooksJSON(
            existingData: existingHooks,
            managedCommand: manifest?.hookCommand
        )

        if hooksMutation.changed, fileManager.fileExists(atPath: hooksURL.path) {
            try backupFile(at: hooksURL)
        }

        if let hooksData = hooksMutation.contents {
            try hooksData.write(to: hooksURL, options: .atomic)
        } else if fileManager.fileExists(atPath: hooksURL.path) {
            try fileManager.removeItem(at: hooksURL)
        }

        if let manifest, manifest.enabledCodexHooksFeature, !hooksMutation.hasRemainingHooks {
            let existingConfig = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
            let featureMutation = CodexHookInstaller.disableCodexHooksFeatureIfManaged(in: existingConfig)
            if featureMutation.changed {
                if fileManager.fileExists(atPath: configURL.path) {
                    try backupFile(at: configURL)
                }
                try featureMutation.contents.write(to: configURL, atomically: true, encoding: .utf8)
            }
        }

        for candidate in [primaryManifestURL, legacyManifestURL] where fileManager.fileExists(atPath: candidate.path) {
            try fileManager.removeItem(at: candidate)
        }

        return try status()
    }

    // MARK: - Private

    private func loadManifest(at url: URL) throws -> CodexHookInstallerManifest? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CodexHookInstallerManifest.self, from: data)
    }

    private func resolvedManifestURL() -> URL {
        let primaryURL = codexDirectory.appendingPathComponent(CodexHookInstallerManifest.fileName)
        if fileManager.fileExists(atPath: primaryURL.path) { return primaryURL }
        let legacyURL = codexDirectory.appendingPathComponent(CodexHookInstallerManifest.legacyFileName)
        return fileManager.fileExists(atPath: legacyURL.path) ? legacyURL : primaryURL
    }

    private func backupFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: .now).replacingOccurrences(of: ":", with: "-")
        let backupURL = url.appendingPathExtension("backup.\(timestamp)")
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }
        try fileManager.copyItem(at: url, to: backupURL)
    }
}
