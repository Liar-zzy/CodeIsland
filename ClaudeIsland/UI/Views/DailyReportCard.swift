//
//  DailyReportCard.swift
//  ClaudeIsland
//
//  Renders "yesterday" and "this week" Claude activity as a compact card
//  at the top of the notch menu. Observes `AnalyticsCollector.shared`.
//  Hides itself completely on quiet periods so the menu doesn't show a
//  sad empty state.
//
//  Two modes via a small segmented control in the header:
//    - .day  — yesterday's numbers + Skills/MCP breakdowns
//    - .week — 7-day totals + sparkline + highlights + streak + vs-last-week
//

import SwiftUI

struct DailyReportCard: View {
    @ObservedObject private var analytics = AnalyticsCollector.shared
    /// Parent view model — used to publish the current card state so the
    /// notch menu window can resize itself to fit the actual content.
    @ObservedObject var viewModel: NotchViewModel
    @State private var mode: Mode = .day
    @State private var isHovered = false
    /// Hero layout is the default: only header + one inline stats line
    /// + one context line. Tapping "查看更多" expands to the full
    /// breakdown (metrics grid, sparkline, highlights, comparisons).
    @State private var isExpanded = false

    enum Mode { case day, week }

    var body: some View {
        Group {
            if !analytics.hasLoadedOnce {
                // First launch — scan is still running in the background. Show a
                // playful pixel cat card so the menu feels alive instead of empty.
                loadingCard
            } else if let week = analytics.thisWeek, week.hasActivity {
                content(week: week, lastWeek: analytics.lastWeek)
            } else {
                // Scan finished but the user has no activity in the last 14 days —
                // render nothing so the menu stays compact.
                EmptyView()
            }
        }
        .onAppear { syncViewModelState() }
        .onChange(of: analytics.hasLoadedOnce) { _, _ in syncViewModelState() }
        .onChange(of: analytics.thisWeek) { _, _ in syncViewModelState() }
        .onChange(of: isExpanded) { _, _ in syncViewModelState() }
        .onChange(of: mode) { _, _ in syncViewModelState() }
    }

    /// Push the current card state into the view model so the menu window
    /// can size itself. Called on every relevant change (load / expand /
    /// mode flip / activity presence).
    private func syncViewModelState() {
        let state: NotchViewModel.DailyReportState
        if !analytics.hasLoadedOnce {
            state = .loading
        } else if let week = analytics.thisWeek, week.hasActivity {
            if !isExpanded {
                state = .collapsed
            } else if mode == .day {
                state = .expandedDay
            } else {
                state = .expandedWeek
            }
        } else {
            state = .hidden
        }
        if viewModel.dailyReportState != state {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                viewModel.dailyReportState = state
            }
        }
    }

    // MARK: - Loading card

    /// Shown while `AnalyticsCollector` is doing its first 14-day JSONL crawl.
    /// Uses `NeonPixelCatView` — the branded pixel cat with a cyberpunk
    /// lime → cyan → magenta wave and an outer neon glow. Cross-fades into
    /// the real report once data arrives.
    private var loadingCard: some View {
        HStack(spacing: 10) {
            // Double-frame trick: inner frame is the cat's natural canvas
            // size, scaleEffect halves the rendering, outer frame tells
            // layout the actual occupied space (otherwise scaleEffect
            // leaves empty padding around the scaled view).
            NeonPixelCatView()
                .frame(width: NeonPixelCatView.canvasW, height: NeonPixelCatView.canvasH)
                .scaleEffect(0.5)
                .frame(width: NeonPixelCatView.canvasW * 0.5,
                       height: NeonPixelCatView.canvasH * 0.5)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundColor(NotchMenuView.brandLime)
                    Text(L10n.analyzingTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                }
                Text(L10n.analyzingSubtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                // Faint animated shimmer bar so the card shows it's "working"
                // even if the user can't see the cat clearly.
                shimmerBar
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(NotchMenuView.brandLime.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(NotchMenuView.brandLime.opacity(0.25), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
        .transition(.opacity)
    }

    /// 2-pt tall shimmer bar that sweeps a lime highlight across a faint
    /// background — cheap indeterminate progress indicator, purely decorative.
    private var shimmerBar: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = CGFloat((sin(t * 2.0) + 1) / 2)  // 0 → 1 → 0 loop
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(NotchMenuView.brandLime.opacity(0.7))
                        .frame(width: geo.size.width * 0.35)
                        .offset(x: phase * (geo.size.width * 0.65))
                }
            }
            .frame(height: 2)
        }
    }

    // MARK: - Root

    /// Hero-first layout: collapsed view shows only the header, one inline
    /// stats line and a single context line. Tapping the "Show more"
    /// toggle reveals the full detail body (sparkline, highlights, etc).
    ///
    /// Color language is deliberately restrained now: lime only appears on
    /// the header icon, the context-line icons and the active segmented
    /// tab. Everything else is white-on-dark opacity gradients — cleaner
    /// and less "spammy green" than the previous version.
    @ViewBuilder
    private func content(week: WeeklyReport, lastWeek: WeeklyReport?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(week: week)
            heroLine(week: week)
            contextLine(week: week)

            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 2)

                if mode == .day {
                    dayBody(report: week.days.last ?? DailyReport.empty(date: Date()))
                } else {
                    weekBody(week: week, lastWeek: lastWeek)
                }
            }

            expandToggle
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isHovered ? 0.05 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
        .onHover { isHovered = $0 }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Hero line + context line + expand toggle

    /// One-line headline stats: `1951 轮 · 11h8m · 36724 行`.
    /// In day mode these are yesterday's numbers, in week mode they're
    /// the 7-day totals.
    private func heroLine(week: WeeklyReport) -> some View {
        let isDay = mode == .day
        let yesterday = week.days.last
        let turns = isDay ? (yesterday?.turnCount ?? 0) : week.turnCount
        let focus = isDay ? (yesterday?.focusMinutes ?? 0) : week.focusMinutes
        let lines = isDay ? (yesterday?.linesWritten ?? 0) : week.linesWritten

        return HStack(spacing: 0) {
            heroStat(value: "\(turns)", label: L10n.turnsLabel)
            heroSeparator
            heroStat(value: Self.formatMinutes(focus), label: L10n.focusLabel)
            heroSeparator
            heroStat(value: "\(lines)", label: L10n.linesLabel)
            Spacer(minLength: 0)
        }
    }

    private func heroStat(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.45))
        }
    }

    private var heroSeparator: some View {
        Text("·")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.2))
            .padding(.horizontal, 6)
    }

    /// Single-line context row underneath the hero: primary project and
    /// either yesterday's longest focus burst (day mode) or the streak
    /// (week mode). Nothing else — keeps the collapsed card to 4 rows max.
    @ViewBuilder
    private func contextLine(week: WeeklyReport) -> some View {
        let items: [(String, String)] = Self.contextItems(week: week, isDay: mode == .day)
        if !items.isEmpty {
            HStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 4) {
                        Image(systemName: item.0)
                            .font(.system(size: 9))
                            .foregroundColor(NotchMenuView.brandLime.opacity(0.75))
                        Text(item.1)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private static func contextItems(week: WeeklyReport, isDay: Bool) -> [(String, String)] {
        var out: [(String, String)] = []
        if isDay {
            if let yesterday = week.days.last {
                if let project = yesterday.primaryProjectName {
                    out.append(("folder.fill", project))
                }
                if yesterday.peakBurstMinutes > 0 {
                    out.append(("flame.fill", "\(formatMinutes(yesterday.peakBurstMinutes)) \(L10n.peakBurstLabel)"))
                }
            }
        } else {
            if let project = week.primaryProjectName {
                out.append(("folder.fill", project))
            }
            if week.streak > 0 {
                out.append(("flame.fill", "\(L10n.streakLabel) \(L10n.streakDays(week.streak))"))
            }
        }
        return out
    }

    /// Bottom-right toggle for expanding the detail body. Hidden chevron
    /// + tiny label so it doesn't compete with the hero numbers.
    private var expandToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Spacer()
                Text(isExpanded ? L10n.collapseLabel : L10n.expandLabel)
                    .font(.system(size: 9, weight: .medium))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header (label + segmented control)

    private func header(week: WeeklyReport) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(NotchMenuView.brandLime)
            Text(mode == .day ? L10n.yesterdayLabel : L10n.weekViewTab)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            segmentedControl
        }
    }

    /// Two-button segmented control for switching between day/week views.
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton(title: L10n.dayViewTab, isActive: mode == .day) {
                withAnimation(.easeInOut(duration: 0.18)) { mode = .day }
            }
            segmentButton(title: L10n.weekViewTab, isActive: mode == .week) {
                withAnimation(.easeInOut(duration: 0.18)) { mode = .week }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func segmentButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .black : .white.opacity(0.6))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? NotchMenuView.brandLime : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day body (expanded detail)
    //
    // The hero line + context line already show turns / focus / lines and
    // primary project, so the expanded section deliberately skips those:
    // it's meant for *extra* info only — secondary pills and
    // Skills/MCP breakdowns.

    @ViewBuilder
    private func dayBody(report: DailyReport) -> some View {
        secondaryStatsRow(
            projectCount: report.projectCount,
            peakBurstMinutes: report.peakBurstMinutes,
            filesEdited: report.filesEdited,
            peakHour: report.peakHour
        )
        breakdownSections(
            skills: report.skillCounts,
            mcps: report.mcpServerCounts
        )
    }

    // MARK: - Week body (expanded detail)

    @ViewBuilder
    private func weekBody(week: WeeklyReport, lastWeek: WeeklyReport?) -> some View {
        sparkline(days: week.days)
        secondaryStatsRow(
            projectCount: week.projectCount,
            peakBurstMinutes: week.peakBurstMinutes,
            filesEdited: week.filesEdited,
            peakHour: nil
        )
        weekHighlights(week: week)
        breakdownSections(
            skills: week.skillCounts,
            mcps: week.mcpServerCounts
        )
        if let lastWeek, lastWeek.hasActivity {
            vsLastWeekRow(thisWeek: week, lastWeek: lastWeek)
        }
    }

    // MARK: - Shared primitives

    @ViewBuilder
    private func metricsGrid(turns: Int, focusMinutes: Int, lines: Int, sessions: Int) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6),
        ], spacing: 6) {
            metricCell(icon: "bubble.left.and.bubble.right.fill",
                       value: "\(turns)", label: L10n.turnsLabel)
            metricCell(icon: "clock.fill",
                       value: Self.formatMinutes(focusMinutes), label: L10n.focusLabel)
            metricCell(icon: "chevron.left.forwardslash.chevron.right",
                       value: "\(lines)", label: L10n.linesLabel)
            metricCell(icon: "square.stack.3d.up.fill",
                       value: "\(sessions)", label: L10n.sessionsLabel)
        }
    }

    private func metricCell(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(NotchMenuView.brandLime.opacity(0.85))
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.3)
                    .foregroundColor(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Secondary pills

    @ViewBuilder
    private func secondaryStatsRow(projectCount: Int, peakBurstMinutes: Int, filesEdited: Int, peakHour: Int?) -> some View {
        let pills: [(String, String, String)] = {
            var out: [(String, String, String)] = []
            if projectCount > 0 {
                out.append(("folder.fill", L10n.projectsLabel, "\(projectCount)"))
            }
            if peakBurstMinutes > 0 {
                out.append(("flame.fill", L10n.peakBurstLabel, Self.formatMinutes(peakBurstMinutes)))
            }
            if filesEdited > 0 {
                out.append(("doc.text.fill", L10n.filesLabel, "\(filesEdited)"))
            }
            if let hour = peakHour {
                out.append(("sun.max.fill", L10n.peakHourLabel, String(format: "%02d:00", hour)))
            }
            return out
        }()

        if !pills.isEmpty {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
            ], spacing: 4) {
                ForEach(Array(pills.enumerated()), id: \.offset) { _, pill in
                    statPill(icon: pill.0, label: pill.1, value: pill.2)
                }
            }
        }
    }

    private func statPill(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(NotchMenuView.brandLime.opacity(0.75))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
            Spacer(minLength: 2)
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Breakdown sections (Skills / MCP)

    /// Breakdown of skill invocations and MCP plugin calls. Built-in tool
    /// counts (Bash/Edit/Read/Grep/...) are deliberately excluded — they
    /// don't carry useful signal, every session uses them.
    @ViewBuilder
    private func breakdownSections(skills: [String: Int], mcps: [String: Int]) -> some View {
        if !skills.isEmpty {
            captionedRow(
                header: L10n.topSkillsHeader,
                icon: "sparkles",
                iconColor: NotchMenuView.brandLime.opacity(0.85),
                text: Self.topN(skills, n: 3),
                monospaced: true
            )
        }
        if !mcps.isEmpty {
            captionedRow(
                header: L10n.topMCPHeader,
                icon: "bolt.horizontal.fill",
                iconColor: NotchMenuView.brandLime.opacity(0.85),
                text: Self.topN(mcps, n: 3),
                monospaced: true
            )
        }
    }

    /// Generic "uppercase caption + icon + text line" block used for
    /// breakdowns and the primary-project row.
    private func captionedRow(header: String, icon: String, iconColor: Color, text: String, monospaced: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(header)
                .font(.system(size: 8, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundColor(.white.opacity(0.4))
            // Top-aligned so that a wrapping multi-line text (e.g. a long
            // list of Skills) doesn't push the icon to the middle.
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(iconColor)
                    .padding(.top, 1)
                Text(text)
                    .font(.system(size: 10, design: monospaced ? .monospaced : .default))
                    .foregroundColor(.white.opacity(0.8))
                    // Allow wrapping: unbounded line count + fixedSize
                    // vertical so the Text reports its natural wrapped
                    // height to the layout system.
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Week-only widgets

    /// 7 vertical bars showing focus minutes per day. The max in the week is
    /// normalized to full height, so days are relative — easier to read than
    /// comparing absolute minutes at tiny pixel scale.
    ///
    /// The header shows the unit (focus minutes) AND the normalization
    /// ceiling — e.g. `DAILY FOCUS · max 4h13m` — so a user glancing at
    /// the chart knows what scale it's on without hovering anything.
    private func sparkline(days: [DailyReport]) -> some View {
        let focusValues = days.map(\.focusMinutes)
        let maxFocus = max(1, focusValues.max() ?? 1)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(L10n.sparklineLabel)
                    .font(.system(size: 8, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundColor(.white.opacity(0.4))
                Text("·")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.2))
                Text("\(L10n.sparklineMaxPrefix) \(Self.formatMinutes(maxFocus))")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Spacer(minLength: 0)
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 2) {
                        let ratio = Double(day.focusMinutes) / Double(maxFocus)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(day.hasActivity
                                  ? NotchMenuView.brandLime.opacity(0.7)
                                  : Color.white.opacity(0.08))
                            .frame(height: max(2, CGFloat(ratio) * 30))
                        Text(Self.shortWeekdayLabel(for: day.date))
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 44)
        }
    }

    /// Fire-emoji-style streak counter. Rendered inline as a pill.
    private func streakBadge(streak: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .font(.system(size: 9))
                .foregroundColor(streak > 0 ? NotchMenuView.brandLime : .white.opacity(0.35))
            Text(L10n.streakLabel)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
            Spacer(minLength: 2)
            Text(L10n.streakDays(streak))
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(streak > 0 ? .white.opacity(0.9) : .white.opacity(0.4))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(streak > 0 ? NotchMenuView.brandLime.opacity(0.1) : Color.white.opacity(0.04))
        )
    }

    /// Peak day + longest focus burst + main project of the week.
    @ViewBuilder
    private func weekHighlights(week: WeeklyReport) -> some View {
        let lines: [String] = {
            var out: [String] = []
            if let peakDay = week.peakDay {
                out.append(L10n.peakDayHighlight(
                    Self.weekdayLabel(for: peakDay.date),
                    turns: peakDay.turnCount
                ))
            }
            if let peakBurstDate = week.peakBurstDate, week.peakBurstMinutes > 0 {
                out.append(L10n.peakBurstHighlight(
                    Self.weekdayLabel(for: peakBurstDate),
                    minutes: Self.formatMinutes(week.peakBurstMinutes)
                ))
            }
            if let project = week.primaryProjectName {
                out.append(L10n.primaryProjectHighlight(project))
            }
            return out
        }()

        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.weekHighlightsHeader)
                    .font(.system(size: 8, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundColor(.white.opacity(0.4))
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 5) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 8))
                            .foregroundColor(NotchMenuView.brandLime.opacity(0.8))
                        Text(line)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    /// Delta pills comparing this week's headline numbers to last week's.
    @ViewBuilder
    private func vsLastWeekRow(thisWeek: WeeklyReport, lastWeek: WeeklyReport) -> some View {
        let deltas: [(String, Int, Int)] = [
            (L10n.turnsLabel,  thisWeek.turnCount,    lastWeek.turnCount),
            (L10n.focusLabel,  thisWeek.focusMinutes, lastWeek.focusMinutes),
            (L10n.linesLabel,  thisWeek.linesWritten, lastWeek.linesWritten),
        ]

        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.vsLastWeekHeader)
                .font(.system(size: 8, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundColor(.white.opacity(0.4))
            HStack(spacing: 4) {
                ForEach(Array(deltas.enumerated()), id: \.offset) { _, d in
                    deltaPill(label: d.0, now: d.1, prev: d.2)
                }
            }
        }
    }

    private func deltaPill(label: String, now: Int, prev: Int) -> some View {
        let delta: Int = now - prev
        let pct: Int = prev > 0 ? Int(((Double(now) - Double(prev)) / Double(prev) * 100).rounded()) : (now > 0 ? 100 : 0)
        let isUp = delta > 0
        let isDown = delta < 0
        let arrow = isUp ? "arrow.up" : (isDown ? "arrow.down" : "minus")
        let tint: Color = isUp ? NotchMenuView.brandLime : (isDown ? Color(red: 1.0, green: 0.45, blue: 0.45) : .white.opacity(0.4))

        return HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.5))
            Image(systemName: arrow)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(tint)
            Text("\(abs(pct))%")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(tint)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Formatting helpers

    private static func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h)h" }
        return "\(h)h\(m)m"
    }

    /// Top-N tool/skill/mcp summary: "name×count · name×count · name×count"
    private static func topN(_ counts: [String: Int], n: Int) -> String {
        let sorted = counts.sorted { $0.value > $1.value }.prefix(n)
        return sorted.map { "\($0.key)×\($0.value)" }.joined(separator: " · ")
    }

    /// Short three-letter weekday name (Mon, Tue, ...). Uses the system locale.
    private static func shortWeekdayLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"  // locale-aware short weekday
        return f.string(from: date)
    }

    /// Full weekday name (Monday, Tuesday, ...). Used by highlight strings.
    private static func weekdayLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}
