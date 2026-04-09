//
//  CodexHooks.swift
//  ClaudeIsland
//
//  Codex hook payload models and runtime context enrichment.
//  Mirrors the Codex hook JSON schema for SessionStart, UserPromptSubmit, and Stop events.
//

import Foundation

// MARK: - Hook Event Names

enum CodexHookEventName: String, Codable, Sendable {
    case sessionStart = "SessionStart"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case userPromptSubmit = "UserPromptSubmit"
    case stop = "Stop"
}

// MARK: - Permission Mode

enum CodexPermissionMode: String, Codable, Sendable {
    case `default`
    case acceptEdits
    case plan
    case dontAsk
    case bypassPermissions
}

// MARK: - Tool Input

struct CodexHookToolInput: Equatable, Codable, Sendable {
    var command: String

    init(command: String) {
        self.command = command
    }
}

// MARK: - Dynamic JSON Value

enum CodexHookJSONValue: Equatable, Codable, Sendable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case object([String: CodexHookJSONValue])
    case array([CodexHookJSONValue])
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: CodexHookJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([CodexHookJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value.")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .boolean(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Hook Payload

struct CodexHookPayload: Equatable, Codable, Sendable {
    var cwd: String
    var hookEventName: CodexHookEventName
    var model: String
    var permissionMode: CodexPermissionMode
    var sessionID: String
    var terminalApp: String?
    var terminalSessionID: String?
    var terminalTTY: String?
    var terminalTitle: String?
    var transcriptPath: String?
    var source: String?
    var turnID: String?
    var toolName: String?
    var toolUseID: String?
    var toolInput: CodexHookToolInput?
    var toolResponse: CodexHookJSONValue?
    var prompt: String?
    var stopHookActive: Bool?
    var lastAssistantMessage: String?

    private enum CodingKeys: String, CodingKey {
        case cwd
        case hookEventName = "hook_event_name"
        case model
        case permissionMode = "permission_mode"
        case sessionID = "session_id"
        case terminalApp = "terminal_app"
        case terminalSessionID = "terminal_session_id"
        case terminalTTY = "terminal_tty"
        case terminalTitle = "terminal_title"
        case transcriptPath = "transcript_path"
        case source
        case turnID = "turn_id"
        case toolName = "tool_name"
        case toolUseID = "tool_use_id"
        case toolInput = "tool_input"
        case toolResponse = "tool_response"
        case prompt
        case stopHookActive = "stop_hook_active"
        case lastAssistantMessage = "last_assistant_message"
    }

    init(
        cwd: String,
        hookEventName: CodexHookEventName,
        model: String,
        permissionMode: CodexPermissionMode,
        sessionID: String,
        terminalApp: String? = nil,
        terminalSessionID: String? = nil,
        terminalTTY: String? = nil,
        terminalTitle: String? = nil,
        transcriptPath: String? = nil,
        source: String? = nil,
        turnID: String? = nil,
        toolName: String? = nil,
        toolUseID: String? = nil,
        toolInput: CodexHookToolInput? = nil,
        toolResponse: CodexHookJSONValue? = nil,
        prompt: String? = nil,
        stopHookActive: Bool? = nil,
        lastAssistantMessage: String? = nil
    ) {
        self.cwd = cwd
        self.hookEventName = hookEventName
        self.model = model
        self.permissionMode = permissionMode
        self.sessionID = sessionID
        self.terminalApp = terminalApp
        self.terminalSessionID = terminalSessionID
        self.terminalTTY = terminalTTY
        self.terminalTitle = terminalTitle
        self.transcriptPath = transcriptPath
        self.source = source
        self.turnID = turnID
        self.toolName = toolName
        self.toolUseID = toolUseID
        self.toolInput = toolInput
        self.toolResponse = toolResponse
        self.prompt = prompt
        self.stopHookActive = stopHookActive
        self.lastAssistantMessage = lastAssistantMessage
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cwd = try container.decode(String.self, forKey: .cwd)
        hookEventName = try container.decode(CodexHookEventName.self, forKey: .hookEventName)
        model = try container.decode(String.self, forKey: .model)
        permissionMode = try container.decodeIfPresent(CodexPermissionMode.self, forKey: .permissionMode) ?? .default
        sessionID = try container.decode(String.self, forKey: .sessionID)
        terminalApp = try container.decodeIfPresent(String.self, forKey: .terminalApp)
        terminalSessionID = try container.decodeIfPresent(String.self, forKey: .terminalSessionID)
        terminalTTY = try container.decodeIfPresent(String.self, forKey: .terminalTTY)
        terminalTitle = try container.decodeIfPresent(String.self, forKey: .terminalTitle)
        transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        turnID = try container.decodeIfPresent(String.self, forKey: .turnID)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        toolUseID = try container.decodeIfPresent(String.self, forKey: .toolUseID)
        toolInput = try container.decodeIfPresent(CodexHookToolInput.self, forKey: .toolInput)
        toolResponse = try container.decodeIfPresent(CodexHookJSONValue.self, forKey: .toolResponse)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        stopHookActive = try container.decodeIfPresent(Bool.self, forKey: .stopHookActive)
        lastAssistantMessage = try container.decodeIfPresent(String.self, forKey: .lastAssistantMessage)
    }
}

// MARK: - Derived Properties

extension CodexHookPayload {
    var workspaceName: String {
        CodexWorkspaceNameResolver.workspaceName(for: cwd)
    }

    var worktreeBranch: String? {
        CodexWorkspaceNameResolver.worktreeBranch(for: cwd)
    }

    var sessionTitle: String {
        "Codex · \(workspaceName)"
    }

    var defaultCodexMetadata: CodexSessionMetadata {
        CodexSessionMetadata(
            transcriptPath: transcriptPath,
            initialUserPrompt: prompt ?? promptPreview,
            lastUserPrompt: prompt ?? promptPreview,
            lastAssistantMessage: lastAssistantMessage,
            currentTool: toolName,
            currentCommandPreview: commandPreview
        )
    }

    var implicitStartSummary: String {
        switch hookEventName {
        case .sessionStart:
            if source == "resume" {
                return "Resumed Codex session in \(workspaceName)."
            }
            return "Started Codex session in \(workspaceName)."
        case .preToolUse:
            return "Codex is preparing a Bash command in \(workspaceName)."
        case .postToolUse:
            return "Codex reported a Bash result in \(workspaceName)."
        case .userPromptSubmit:
            return "Codex received a new prompt in \(workspaceName)."
        case .stop:
            return "Codex completed a turn in \(workspaceName)."
        }
    }

    var commandText: String? { toolInput?.command }
    var commandPreview: String? { clipped(commandText) }
    var promptPreview: String? { clipped(prompt) }
    var assistantMessagePreview: String? { clipped(lastAssistantMessage) }

    var toolResponsePreview: String? {
        guard let toolResponse else { return nil }
        return clipped(stringValue(for: toolResponse))
    }

    private func clipped(_ value: String?, limit: Int = 110) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        guard collapsed.count > limit else { return collapsed }
        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: limit - 1)
        return "\(collapsed[..<endIndex])…"
    }

    private func stringValue(for value: CodexHookJSONValue) -> String {
        switch value {
        case let .string(text): return text
        case let .number(number): return String(number)
        case let .boolean(flag): return flag ? "true" : "false"
        case .null: return "null"
        case let .array(items):
            return "[\(items.map(stringValue(for:)).joined(separator: ", "))]"
        case let .object(object):
            let rendered = object.keys.sorted()
                .map { key in "\(key): \(object[key].map(stringValue(for:)) ?? "null")" }
                .joined(separator: ", ")
            return "{\(rendered)}"
        }
    }
}

// MARK: - Runtime Context Enrichment

extension CodexHookPayload {
    func withRuntimeContext(environment: [String: String]) -> CodexHookPayload {
        withRuntimeContext(
            environment: environment,
            currentTTYProvider: { currentTTY() },
            terminalLocatorProvider: { terminalLocator(for: $0) }
        )
    }

    func withRuntimeContext(
        environment: [String: String],
        currentTTYProvider: () -> String?,
        terminalLocatorProvider: (String) -> (sessionID: String?, tty: String?, title: String?)
    ) -> CodexHookPayload {
        var payload = self

        if payload.terminalApp == nil {
            payload.terminalApp = inferTerminalApp(from: environment)
        }

        if payload.terminalApp == "cmux", payload.terminalSessionID == nil {
            payload.terminalSessionID = environment["CMUX_SURFACE_ID"]
        }

        if isZellijTerminalApp(payload.terminalApp), payload.terminalSessionID == nil {
            let paneID = environment["ZELLIJ_PANE_ID"] ?? ""
            let sessionName = environment["ZELLIJ_SESSION_NAME"] ?? ""
            if !paneID.isEmpty {
                payload.terminalSessionID = "\(paneID):\(sessionName)"
            }
        }

        if payload.terminalTTY == nil {
            payload.terminalTTY = currentTTYProvider()
        }

        let useLocator: Bool
        if isCmuxTerminalApp(payload.terminalApp) || isZellijTerminalApp(payload.terminalApp) {
            useLocator = false
        } else if let terminalApp = payload.terminalApp, isGhosttyTerminalApp(terminalApp) {
            if payload.hookEventName == .sessionStart || payload.hookEventName == .userPromptSubmit {
                useLocator = true
            } else {
                payload.terminalSessionID = nil
                payload.terminalTitle = nil
                useLocator = false
            }
        } else {
            useLocator = shouldUseFocusedTerminalLocator(for: payload.terminalApp ?? "")
        }

        if useLocator, let terminalApp = payload.terminalApp {
            let locator = terminalLocatorProvider(terminalApp)
            if payload.terminalSessionID == nil { payload.terminalSessionID = locator.sessionID }
            if payload.terminalTTY == nil { payload.terminalTTY = locator.tty }
            if payload.terminalTitle == nil { payload.terminalTitle = locator.title }
        }

        return payload
    }

    private static let noLocatorTerminalApps: Set<String> = [
        "cmux", "kaku", "wezterm", "zellij",
        "vs code", "vs code insiders", "cursor", "windsurf", "trae",
        "intellij idea", "webstorm", "pycharm", "goland", "clion",
        "rubymine", "phpstorm", "rider", "rustrover",
    ]

    private func shouldUseFocusedTerminalLocator(for terminalApp: String) -> Bool {
        let lower = terminalApp.lowercased()
        if lower.contains("ghostty") || lower.contains("jetbrains") { return false }
        return !Self.noLocatorTerminalApps.contains(lower)
    }

    private func isGhosttyTerminalApp(_ terminalApp: String?) -> Bool {
        terminalApp?.lowercased().contains("ghostty") ?? false
    }

    private func isCmuxTerminalApp(_ terminalApp: String?) -> Bool {
        terminalApp?.lowercased() == "cmux"
    }

    private func isZellijTerminalApp(_ terminalApp: String?) -> Bool {
        terminalApp?.lowercased() == "zellij"
    }

    private func inferTerminalApp(from environment: [String: String]) -> String? {
        if environment["ITERM_SESSION_ID"] != nil || environment["LC_TERMINAL"] == "iTerm2" { return "iTerm" }
        if environment["CMUX_WORKSPACE_ID"] != nil || environment["CMUX_SOCKET_PATH"] != nil { return "cmux" }
        if environment["ZELLIJ"] != nil { return "Zellij" }
        if environment["GHOSTTY_RESOURCES_DIR"] != nil { return "Ghostty" }
        if environment["WARP_IS_LOCAL_SHELL_SESSION"] != nil { return "Warp" }

        let termProgram = environment["TERM_PROGRAM"]?.lowercased()
        switch termProgram {
        case .some("apple_terminal"): return "Terminal"
        case .some("iterm.app"), .some("iterm2"): return "iTerm"
        case let value? where value.contains("ghostty"): return "Ghostty"
        case let value? where value.contains("warp"): return "Warp"
        case let value? where value.contains("wezterm"): return "WezTerm"
        case .some("kaku"): return "Kaku"
        case .some("vscode"): return "VS Code"
        case .some("vscode-insiders"): return "VS Code Insiders"
        case .some("windsurf"): return "Windsurf"
        case .some("trae"): return "Trae"
        default: break
        }

        if let terminalEmulator = environment["TERMINAL_EMULATOR"]?.lowercased(),
           terminalEmulator.contains("jetbrains") {
            if let bundleID = environment["__CFBundleIdentifier"]?.lowercased() {
                if bundleID.contains("webstorm") { return "WebStorm" }
                if bundleID.contains("pycharm") { return "PyCharm" }
                if bundleID.contains("goland") { return "GoLand" }
                if bundleID.contains("clion") { return "CLion" }
                if bundleID.contains("rubymine") { return "RubyMine" }
                if bundleID.contains("phpstorm") { return "PhpStorm" }
                if bundleID.contains("rider") { return "Rider" }
                if bundleID.contains("rustrover") { return "RustRover" }
                if bundleID.contains("intellij") { return "IntelliJ IDEA" }
            }
            return "IntelliJ IDEA"
        }

        return nil
    }

    private func currentTTY() -> String? {
        if let tty = commandOutput(executablePath: "/usr/bin/tty", arguments: []),
           !tty.contains("not a tty") {
            return tty
        }
        return parentProcessTTY()
    }

    private func parentProcessTTY() -> String? {
        let ppid = getppid()
        guard let raw = commandOutput(executablePath: "/bin/ps", arguments: ["-p", "\(ppid)", "-o", "tty="]) else {
            return nil
        }
        let tty = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tty.isEmpty, tty != "??", tty != "-" else { return nil }
        return tty.hasPrefix("/dev/") ? tty : "/dev/\(tty)"
    }

    private func terminalLocator(for terminalApp: String) -> (sessionID: String?, tty: String?, title: String?) {
        let normalized = terminalApp.lowercased()

        if normalized.contains("iterm") {
            let values = osascriptValues(script: """
            tell application "iTerm"
                if not (it is running) then return ""
                tell current session of current window
                    return (id as text) & (ASCII character 31) & (tty as text) & (ASCII character 31) & (name as text)
                end tell
            end tell
            """)
            return (sessionID: values[safe: 0], tty: values[safe: 1], title: values[safe: 2])
        }

        if normalized.contains("ghostty") {
            let values = osascriptValues(script: """
            tell application "Ghostty"
                if not (it is running) then return ""
                tell focused terminal of selected tab of front window
                    return (id as text) & (ASCII character 31) & (working directory as text) & (ASCII character 31) & (name as text)
                end tell
            end tell
            """)
            return (sessionID: values[safe: 0], tty: nil, title: values[safe: 2])
        }

        if normalized.contains("terminal") {
            let values = osascriptValues(script: """
            tell application "Terminal"
                if not (it is running) then return ""
                tell selected tab of front window
                    return (tty as text) & (ASCII character 31) & (custom title as text)
                end tell
            end tell
            """)
            return (sessionID: nil, tty: values[safe: 0], title: values[safe: 1])
        }

        return (nil, nil, nil)
    }

    private func osascriptValues(script: String) -> [String] {
        guard let raw = commandOutput(executablePath: "/usr/bin/osascript", arguments: ["-e", script]) else {
            return []
        }
        let separator = String(UnicodeScalar(31)!)
        return raw
            .components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func commandOutput(executablePath: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else { return nil }
        return output
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Workspace Name Resolver

enum CodexWorkspaceNameResolver {
    private static let worktreeMarkers = ["/.claude/worktrees/", "/.git/worktrees/"]

    static func workspaceName(for cwd: String) -> String {
        let path = URL(fileURLWithPath: cwd).standardizedFileURL.path
        for marker in worktreeMarkers {
            if let range = path.range(of: marker) {
                let projectName = URL(fileURLWithPath: String(path[path.startIndex ..< range.lowerBound])).lastPathComponent
                if !projectName.isEmpty { return projectName }
            }
        }
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? "Workspace" : name
    }

    static func worktreeBranch(for cwd: String) -> String? {
        let path = URL(fileURLWithPath: cwd).standardizedFileURL.path
        for marker in worktreeMarkers {
            guard let range = path.range(of: marker) else { continue }
            let branch = String(path[range.upperBound...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .replacingOccurrences(of: "+", with: "/")
            return branch.isEmpty ? nil : branch
        }
        return nil
    }
}
