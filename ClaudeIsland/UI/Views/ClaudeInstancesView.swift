//
//  ClaudeInstancesView.swift
//  ClaudeIsland
//
//  Minimal instances list matching Dynamic Island aesthetic
//

import AppKit
import Combine
import SwiftUI

struct ClaudeInstancesView: View {
    @ObservedObject var sessionMonitor: ClaudeSessionMonitor
    @ObservedObject var viewModel: NotchViewModel

    /// Tracks which project groups are collapsed, keyed by group id (cwd path)
    @State private var collapsedGroups: Set<String> = []
    /// Whether to show grouped by project or flat list (default: flat)
    @AppStorage("showGroupedSessions") private var showGrouped: Bool = false
    @ObservedObject private var buddyReader = BuddyReader.shared
    @State private var showBuddyCard: Bool = false

    var body: some View {
        if sessionMonitor.instances.isEmpty {
            emptyState
        } else {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Top bar: session count left, gear right
                    HStack {
                        Text("\(sessionMonitor.instances.count) \(L10n.sessions)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.25))
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                viewModel.toggleMenu()
                            }
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.35))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 28) // Push below camera module

                    if showBuddyCard, let buddy = buddyReader.buddy {
                        buddyCardView(buddy)
                    } else if showGrouped {
                        groupedList
                    } else {
                        flatList
                    }
                }

                // Buddy floating button — bottom right, ASCII art sprite
                if let buddy = buddyReader.buddy {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showBuddyCard.toggle()
                        }
                    } label: {
                        BuddyASCIIView(buddy: buddy)
                            .frame(width: 80, height: 50)
                            .scaleEffect(0.7)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                    .padding(.bottom, 2)
                }
            }
        }
    }

    // MARK: - Buddy Card

    @ViewBuilder
    private func buddyCardView(_ buddy: BuddyInfo) -> some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                Text(buddy.rarity.stars)
                    .font(.system(size: 11))
                    .foregroundColor(buddy.rarity.color)
                Text(buddy.rarity.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(buddy.rarity.color)
                Spacer()
                Text(buddy.species.rawValue.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                if buddy.isShiny {
                    Text("✨")
                        .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 10)

            // Left-right layout: ASCII art | stats
            HStack(alignment: .top, spacing: 8) {
                // Left: ASCII sprite
                VStack(spacing: 2) {
                    BuddyASCIIView(buddy: buddy)
                        .frame(height: 65)
                    Text(buddy.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 100)

                // Right: stats + personality
                VStack(alignment: .leading, spacing: 4) {
                    if buddy.stats.debugging > 0 {
                        asciiStatBar("DBG", value: buddy.stats.debugging, color: .cyan)
                        asciiStatBar("PAT", value: buddy.stats.patience, color: .green)
                        asciiStatBar("CHS", value: buddy.stats.chaos, color: .red)
                        asciiStatBar("WIS", value: buddy.stats.wisdom, color: .purple)
                        asciiStatBar("SNK", value: buddy.stats.snark, color: .orange)
                    }

                    Text(buddy.personality)
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.3))
                        .lineLimit(3)
                        .padding(.top, 3)
                }
            }
            .padding(.horizontal, 8)

            // Back
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showBuddyCard = false
                }
            } label: {
                Text(L10n.back)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    /// ASCII-style stat bar: `DBG [████████░░] 64`
    private func asciiStatBar(_ label: String, value: Int, color: Color) -> some View {
        let filled = value / 10
        let empty = 10 - filled
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)

        return HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 30, alignment: .trailing)
            Text("[\(bar)]")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(color.opacity(0.7))
            Text("\(value)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(color.opacity(0.5))
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(L10n.noSessions)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

            Text(L10n.runClaude)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Instances List

    /// Priority: active (approval/processing/compacting) > waitingForInput > idle
    /// Secondary sort: by last user message date (stable - doesn't change when agent responds)
    /// Note: approval requests stay in their date-based position to avoid layout shift
    private var sortedInstances: [SessionState] {
        sessionMonitor.instances.sorted { a, b in
            let priorityA = phasePriority(a.phase)
            let priorityB = phasePriority(b.phase)
            if priorityA != priorityB {
                return priorityA < priorityB
            }
            // Sort by last user message date (more recent first)
            // Fall back to lastActivity if no user messages yet
            let dateA = a.lastUserMessageDate ?? a.lastActivity
            let dateB = b.lastUserMessageDate ?? b.lastActivity
            return dateA > dateB
        }
    }

    /// Lower number = higher priority
    /// Approval requests share priority with processing to maintain stable ordering
    private func phasePriority(_ phase: SessionPhase) -> Int {
        switch phase {
        case .waitingForApproval, .processing, .compacting: return 0
        case .waitingForInput: return 1
        case .idle, .ended: return 2
        }
    }

    /// Sessions grouped by project (cwd), with per-group sorting preserved
    private var projectGroups: [ProjectGroup] {
        ProjectGroup.group(sessions: sortedInstances)
    }

    private var flatList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(sortedInstances.enumerated()), id: \.element.id) { index, session in
                    InstanceRow(
                        session: session,
                        onFocus: { focusSession(session) },
                        onChat: { openChat(session) },
                        onArchive: { archiveSession(session) },
                        onApprove: { approveSession(session) },
                        onReject: { rejectSession(session) }
                    )
                    .id(session.stableId)

                    // Gradient divider between rows
                    if index < sortedInstances.count - 1 {
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.06), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    }
                }

                // "Show all N sessions" footer
                if sortedInstances.count > 0 {
                    Text(L10n.showAllSessions(sortedInstances.count))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.2))
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var groupedList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 4) {
                ForEach(projectGroups) { group in
                    ProjectGroupHeader(
                        group: group,
                        isCollapsed: collapsedGroups.contains(group.id)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if collapsedGroups.contains(group.id) {
                                collapsedGroups.remove(group.id)
                            } else {
                                collapsedGroups.insert(group.id)
                            }
                        }
                    }

                    if !collapsedGroups.contains(group.id) {
                        ForEach(group.sessions) { session in
                            InstanceRow(
                                session: session,
                                onFocus: { focusSession(session) },
                                onChat: { openChat(session) },
                                onArchive: { archiveSession(session) },
                                onApprove: { approveSession(session) },
                                onReject: { rejectSession(session) }
                            )
                            .id(session.stableId)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Actions

    private func focusSession(_ session: SessionState) {
        Task { await TerminalJumper.shared.jump(to: session) }
    }

    private func openChat(_ session: SessionState) {
        viewModel.showChat(for: session)
    }

    private func approveSession(_ session: SessionState) {
        sessionMonitor.approvePermission(sessionId: session.sessionId)
    }

    private func rejectSession(_ session: SessionState) {
        sessionMonitor.denyPermission(sessionId: session.sessionId, reason: nil)
    }

    private func archiveSession(_ session: SessionState) {
        sessionMonitor.archiveSession(sessionId: session.sessionId)
    }
}

// MARK: - Instance Row

struct InstanceRow: View {
    let session: SessionState
    let onFocus: () -> Void
    let onChat: () -> Void
    let onArchive: () -> Void
    let onApprove: () -> Void
    let onReject: () -> Void

    @State private var isHovered = false

    // MARK: - Colors

    /// Blue pill colors for "Claude" tag
    private static let claudeTagBg = Color(red: 0.145, green: 0.388, blue: 0.922).opacity(0.2) // #2563EB @ 0.2
    private static let claudeTagFg = Color(red: 0.376, green: 0.647, blue: 0.98) // #60A5FA
    private static let cyanColor = Color(red: 0.4, green: 0.91, blue: 0.98)

    /// Whether we're showing the approval UI
    private var isWaitingForApproval: Bool {
        session.phase.isWaitingForApproval
    }

    /// Whether the pending tool requires interactive input (not just approve/deny)
    private var isInteractiveTool: Bool {
        guard let toolName = session.pendingToolName else { return false }
        return toolName == "AskUserQuestion"
    }

    /// Duration since session started, formatted as "<Xm" or "Xh"
    private var durationText: String {
        let elapsed = Date().timeIntervalSince(session.createdAt)
        let minutes = Int(elapsed / 60)
        if minutes < 1 {
            return "<1m"
        }
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        return "\(hours)h"
    }

    /// Terminal app name — auto-detected from process tree
    private var terminalTag: String {
        session.terminalApp ?? (session.isInTmux ? "tmux" : "term")
    }

    /// Accent color based on phase (used for status dot)
    private var accentColor: Color {
        switch session.phase {
        case .processing, .compacting: return Self.cyanColor
        case .waitingForApproval: return Color(red: 0.96, green: 0.62, blue: 0.04) // amber
        case .waitingForInput: return Color(red: 0.29, green: 0.87, blue: 0.5)  // green
        case .idle, .ended: return Color.white.opacity(0.2)
        }
    }

    /// Title text: "projectName · displayTitle" or just projectName if same
    private var titleText: String {
        let display = session.displayTitle
        if display == session.projectName {
            return session.projectName
        }
        return "\(session.projectName) \u{00B7} \(display)"
    }

    @ObservedObject private var buddyReader = BuddyReader.shared
    @AppStorage("usePixelCat") private var usePixelCat: Bool = false

    /// Animation state derived from session phase
    private var animationState: AnimationState {
        switch session.phase {
        case .processing, .compacting: return .working
        case .waitingForApproval: return .needsYou
        case .waitingForInput: return .done
        case .idle, .ended: return .idle
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                // Buddy icon or pixel cat
                ZStack {
                    if usePixelCat {
                        PixelCharacterView(state: animationState)
                            .scaleEffect(0.35)
                    } else if let buddy = buddyReader.buddy {
                        EmojiPixelView(emoji: buddy.species.emoji, style: .rock)
                            .scaleEffect(0.35)
                    } else {
                        PixelCharacterView(state: animationState)
                            .scaleEffect(0.35)
                    }
                    // Status dot overlay
                    Circle()
                        .fill(accentColor)
                        .frame(width: 5, height: 5)
                        .shadow(color: accentColor.opacity(0.6), radius: 2)
                        .offset(x: 8, y: 8)
                }
                .frame(width: 22, height: 22)
                .padding(.top, 2)

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    // Title row
                    HStack(spacing: 4) {
                        Text(titleText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        // Terminal tag — grey pill (shows tmux if in tmux)
                        Text(terminalTag)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.white.opacity(0.06))
                            )

                        // Duration
                        Text(durationText)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))

                        // Terminal jump button — uses onTapGesture to avoid SwiftUI Button hitTest issues
                        Image(systemName: "terminal")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 20, height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { onFocus() }
                    }

                    // Subtitle
                    subtitleView

                    // Approval buttons row when needed
                    if isWaitingForApproval {
                        InlineApprovalButtons(
                            onChat: onChat,
                            onApprove: onApprove,
                            onReject: onReject
                        )
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .onTapGesture { onChat() }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
            )
        }
        .onHover { isHovered = $0 }
    }

    // MARK: - Subtitle

    @ViewBuilder
    private var subtitleView: some View {
        if isWaitingForApproval, let toolName = session.pendingToolName {
            // Approval state: show tool info as subtitle
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 2) {
                    Text(L10n.you)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.35))
                    Text(MCPToolFormatter.formatToolName(toolName))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
                HStack(spacing: 2) {
                    Text("AI ")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Self.cyanColor.opacity(0.7))
                    if isInteractiveTool {
                        Text(L10n.needsInput)
                            .font(.system(size: 9))
                            .foregroundColor(Self.cyanColor.opacity(0.5))
                            .lineLimit(1)
                    } else if let input = session.pendingToolInput {
                        Text(input)
                            .font(.system(size: 9))
                            .foregroundColor(Self.cyanColor.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            }
        } else if let summary = session.smartSummary {
            // Smart summary with role prefixes
            VStack(alignment: .leading, spacing: 1) {
                let parts = summary.components(separatedBy: "\n")
                if parts.count >= 2 {
                    // Line 1: user question
                    HStack(spacing: 0) {
                        Text(L10n.you)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.35))
                        Text(parts[0])
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    // Line 2: AI reply
                    HStack(spacing: 0) {
                        Text("AI ")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Self.cyanColor.opacity(0.7))
                        Text(parts[1])
                            .font(.system(size: 9))
                            .foregroundColor(Self.cyanColor.opacity(0.45))
                            .lineLimit(1)
                    }
                } else {
                    // Single line summary — show as AI line
                    HStack(spacing: 0) {
                        Text("AI ")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Self.cyanColor.opacity(0.7))
                        Text(summary)
                            .font(.system(size: 9))
                            .foregroundColor(Self.cyanColor.opacity(0.45))
                            .lineLimit(1)
                    }
                }
            }
        } else if let role = session.lastMessageRole {
            // Fallback: show last message with role prefix
            VStack(alignment: .leading, spacing: 1) {
                switch role {
                case "user":
                    HStack(spacing: 0) {
                        Text(L10n.you)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.35))
                        if let msg = session.lastMessage {
                            Text(msg)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                    }
                case "tool":
                    HStack(spacing: 0) {
                        Text("AI ")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Self.cyanColor.opacity(0.7))
                        if let toolName = session.lastToolName {
                            Text(MCPToolFormatter.formatToolName(toolName))
                                .font(.system(size: 9))
                                .foregroundColor(Self.cyanColor.opacity(0.45))
                                .lineLimit(1)
                        }
                    }
                default:
                    HStack(spacing: 0) {
                        Text("AI ")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Self.cyanColor.opacity(0.7))
                        if let msg = session.lastMessage {
                            Text(msg)
                                .font(.system(size: 9))
                                .foregroundColor(Self.cyanColor.opacity(0.45))
                                .lineLimit(1)
                        }
                    }
                }
            }
        } else if let lastMsg = session.lastMessage {
            HStack(spacing: 0) {
                Text("AI ")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Self.cyanColor.opacity(0.7))
                Text(lastMsg)
                    .font(.system(size: 9))
                    .foregroundColor(Self.cyanColor.opacity(0.45))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Project Group Header

struct ProjectGroupHeader: View {
    let group: ProjectGroup
    let isCollapsed: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 12)

                Text(group.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                if group.activeCount > 0 {
                    Text("\(group.activeCount) \(L10n.active)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                } else if group.isArchivable {
                    Text(L10n.archived)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                        )
                }

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.04) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Inline Approval Buttons

/// Compact inline approval buttons with staggered animation
struct InlineApprovalButtons: View {
    let onChat: () -> Void
    let onApprove: () -> Void
    let onReject: () -> Void

    @State private var showChatButton = false
    @State private var showDenyButton = false
    @State private var showAllowButton = false

    var body: some View {
        HStack(spacing: 6) {
            // Chat button
            IconButton(icon: "bubble.left") {
                onChat()
            }
            .opacity(showChatButton ? 1 : 0)
            .scaleEffect(showChatButton ? 1 : 0.8)

            Button {
                onReject()
            } label: {
                Text(L10n.deny)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .opacity(showDenyButton ? 1 : 0)
            .scaleEffect(showDenyButton ? 1 : 0.8)

            Button {
                onApprove()
            } label: {
                Text(L10n.allow)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .opacity(showAllowButton ? 1 : 0)
            .scaleEffect(showAllowButton ? 1 : 0.8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.0)) {
                showChatButton = true
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.05)) {
                showDenyButton = true
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1)) {
                showAllowButton = true
            }
        }
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isHovered ? .white.opacity(0.8) : .white.opacity(0.4))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Compact Terminal Button (inline in description)

struct CompactTerminalButton: View {
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            if isEnabled {
                onTap()
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "terminal")
                    .font(.system(size: 12, weight: .medium))
                Text(L10n.goToTerminal)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isEnabled ? .white.opacity(0.9) : .white.opacity(0.3))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isEnabled ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Terminal Button

struct TerminalButton: View {
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            if isEnabled {
                onTap()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "terminal")
                    .font(.system(size: 12, weight: .medium))
                Text(L10n.terminal)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isEnabled ? .black : .white.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isEnabled ? Color.white.opacity(0.95) : Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
