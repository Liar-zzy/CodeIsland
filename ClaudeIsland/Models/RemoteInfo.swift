//
//  RemoteInfo.swift
//  ClaudeIsland
//
//  Metadata for a remote (SSH) Claude Code session forwarded by a relay.
//  This is a standalone model — existing files are not modified.
//

import Foundation

/// Remote session connection metadata reported by codeisland-relay.
/// Nil for local sessions; populated for sessions running on remote servers via SSH.
struct RemoteInfo: Codable, Equatable, Sendable {
    /// Remote server hostname (e.g., "dgx-127")
    let host: String
    /// Remote username (e.g., "zhangzy")
    let user: String
    /// SSH port (default 22)
    let port: Int
    /// SSH config alias (e.g., "hk") — used for matching local ssh processes
    let sshAlias: String?
    /// Multiplexer type
    let muxType: MuxType
    /// Multiplexer session name (e.g., "dev-work")
    let muxSessionName: String
    /// Tab/window index within the multiplexer session
    let muxTabIndex: Int?
    /// Working directory on the remote server
    let remoteCwd: String?
    /// Device ID of the relay that reported this session
    let relayDeviceId: String?

    enum MuxType: String, Codable, Sendable {
        case zellij
        case tmux
        case unknown
    }

    init(
        host: String,
        user: String,
        port: Int = 22,
        sshAlias: String? = nil,
        muxType: MuxType = .unknown,
        muxSessionName: String = "",
        muxTabIndex: Int? = nil,
        remoteCwd: String? = nil,
        relayDeviceId: String? = nil
    ) {
        self.host = host
        self.user = user
        self.port = port
        self.sshAlias = sshAlias
        self.muxType = muxType
        self.muxSessionName = muxSessionName
        self.muxTabIndex = muxTabIndex
        self.remoteCwd = remoteCwd
        self.relayDeviceId = relayDeviceId
    }
}
