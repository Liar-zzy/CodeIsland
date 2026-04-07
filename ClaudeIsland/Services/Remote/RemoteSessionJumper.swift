//
//  RemoteSessionJumper.swift
//  ClaudeIsland
//
//  Handles jumping to remote SSH Claude Code sessions in the local cmux terminal.
//  Uses TTY-based matching to find the correct cmux surface, then four-step
//  navigation: focus-window → select-workspace → focus-pane → tab-action.
//
//  This is a standalone file — no existing files are modified.
//

import Foundation

/// Jumps to a remote session's local terminal (cmux surface with SSH connection).
actor RemoteSessionJumper {

    // MARK: - Public API

    /// Jump to (or open) the local terminal surface connected to this remote session.
    /// Also notifies the relay to focus the correct multiplexer tab on the remote side.
    func jump(to remoteInfo: RemoteInfo, backendFocusHandler: ((RemoteInfo) async -> Void)? = nil) async {
        // Step 1: Try to find an existing SSH surface in cmux
        if let location = await findExistingSSHSurface(for: remoteInfo) {
            await focusCmuxLocation(location)
        } else {
            // Step 2: No existing connection — open a new one
            await openNewConnection(for: remoteInfo)
        }

        // Step 3: Notify relay to focus remote multiplexer tab (parallel)
        await backendFocusHandler?(remoteInfo)
    }

    // MARK: - Find existing SSH surface via TTY matching

    /// Search all cmux surfaces for one whose SSH process connects to the target host.
    private func findExistingSSHSurface(for remote: RemoteInfo) async -> CmuxLocation? {
        // 1. Find SSH processes and their TTYs
        guard let sshTTY = findSSHProcessTTY(host: remote.host, sshAlias: remote.sshAlias) else {
            return nil
        }

        // 2. Parse cmux tree --all
        guard let treeOutput = await runCmux(["tree", "--all"]) else {
            return nil
        }
        let surfaces = CmuxTreeParser.parse(treeOutput)

        // 3. Find surfaces matching the SSH TTY
        let candidates = CmuxTreeParser.findByTTY(sshTTY, in: surfaces)
        if candidates.isEmpty {
            return nil
        }

        // 4. Disambiguate if multiple matches
        if candidates.count == 1 {
            return candidates.first
        }
        return CmuxTreeParser.disambiguateByHost(
            candidates, host: remote.host, sshAlias: remote.sshAlias
        )
    }

    /// Find the TTY of an SSH process connecting to the given host.
    private func findSSHProcessTTY(host: String, sshAlias: String?) -> String? {
        guard let psOutput = runProcess("/bin/ps", args: ["-eo", "pid,tty,args"]) else {
            return nil
        }

        for line in psOutput.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("ssh") else { continue }
            guard !trimmed.contains("grep") else { continue }

            let matchesHost = trimmed.localizedCaseInsensitiveContains(host)
            let matchesAlias = sshAlias.map { trimmed.localizedCaseInsensitiveContains($0) } ?? false

            if matchesHost || matchesAlias {
                let tokens = trimmed.split(separator: " ", maxSplits: 2)
                if tokens.count >= 2 {
                    return String(tokens[1])  // TTY column
                }
            }
        }
        return nil
    }

    // MARK: - Four-step cmux navigation

    private func focusCmuxLocation(_ location: CmuxLocation) async {
        // 1. Focus the OS-level window
        await runCmux(["focus-window", "--window", location.windowRef])

        // 2. Select the workspace
        await runCmux(["select-workspace", "--workspace", location.workspaceRef])

        // 3. Focus the pane (split area)
        await runCmux(["focus-pane", "--pane", location.paneRef,
                        "--workspace", location.workspaceRef])

        // 4. Select the surface (tab)
        await runCmux(["tab-action", "--action", "select",
                        "--surface", location.surfaceRef,
                        "--workspace", location.workspaceRef])
    }

    // MARK: - Open new SSH + multiplexer connection

    private func openNewConnection(for remote: RemoteInfo) async {
        let sshTarget = remote.sshAlias ?? "\(remote.user)@\(remote.host)"
        let attachCmd: String

        switch remote.muxType {
        case .zellij:
            // Use bash -l -c to ensure zellij is in PATH (verified: direct ssh -t fails)
            let zellijCmd = "zellij attach \(remote.muxSessionName) 2>/dev/null || zellij --session \(remote.muxSessionName)"
            attachCmd = "ssh -t \(sshTarget) 'bash -l -c \"\(zellijCmd)\"'"
        case .tmux:
            let tmuxCmd = "tmux attach-session -t \(remote.muxSessionName) || tmux new-session -s \(remote.muxSessionName)"
            attachCmd = "ssh -t \(sshTarget) 'bash -l -c \"\(tmuxCmd)\"'"
        case .unknown:
            attachCmd = "ssh \(sshTarget)"
        }

        let workspaceName = "\(remote.host):\(remote.muxSessionName)"
        await runCmux(["new-workspace", "--name", workspaceName, "--command", attachCmd])
    }

    // MARK: - Process helpers

    @discardableResult
    private func runCmux(_ args: [String]) async -> String? {
        let paths = [
            "/Applications/cmux.app/Contents/Resources/bin/cmux",
            "/opt/homebrew/bin/cmux",
            "/usr/local/bin/cmux",
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return runProcess(path, args: args)
            }
        }
        return runProcess("cmux", args: args)
    }

    private func runProcess(_ path: String, args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
