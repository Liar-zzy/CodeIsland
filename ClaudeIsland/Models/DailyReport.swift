//
//  DailyReport.swift
//  ClaudeIsland
//
//  Aggregated "what did Claude do for you yesterday" numbers, computed once
//  a day from the per-session JSONL files under ~/.claude/projects/.
//

import Foundation

/// A single day's activity summary. Produced by `AnalyticsCollector` and
/// displayed in the `DailyReportCard` at the top of the notch menu.
struct DailyReport: Equatable, Sendable, Codable {
    /// The local calendar day this report covers — always yesterday relative
    /// to the time the report was computed. (We deliberately never report
    /// "today" because today's data is still in flight and would be misleading.)
    let date: Date

    /// Number of distinct Claude sessions that had at least one turn on this day.
    let sessionCount: Int

    /// Number of user turns (each user prompt counts as one turn).
    let turnCount: Int

    /// Minutes the user was actively working with Claude. Computed by
    /// grouping consecutive messages within each session into "bursts"
    /// (gap < 5 minutes) and summing burst durations. Idle time between
    /// bursts is NOT counted, so this is a realistic "focus time" number
    /// rather than "the session was open for 4 hours".
    let focusMinutes: Int

    /// Built-in tool usage breakdown, keyed by tool name (e.g. "Bash" → 34).
    /// Only counts the core toolset — Skill invocations and MCP calls live in
    /// their own buckets below so "top tools" can distinguish the three.
    let toolCounts: [String: Int]

    /// Skill invocations, keyed by the `input.skill` value of `Skill` tool
    /// calls. e.g. `commit → 12`, `review-pr → 5`.
    let skillCounts: [String: Int]

    /// MCP plugin calls grouped by server name. e.g. `devforge → 47` rolls up
    /// every `mcp__devforge__*` call from that day.
    let mcpServerCounts: [String: Int]

    /// Total lines of code Claude wrote on this day. Summed from the
    /// `new_string` of every Edit / MultiEdit invocation and the full
    /// `content` of every Write invocation.
    let linesWritten: Int

    /// The folder name (last path component of cwd) with the most turns
    /// on this day. Nil if there was no activity.
    let primaryProjectName: String?

    /// Number of distinct projects (cwd folder names) touched on this day.
    let projectCount: Int

    /// Duration of the longest single focus burst, in minutes. Gives a sense
    /// of "deep work" — the longest uninterrupted stretch you worked with Claude.
    let peakBurstMinutes: Int

    /// Number of distinct files touched by Write/Edit/MultiEdit on this day.
    let filesEdited: Int

    /// Hour of day (0–23, local time) with the most user turns. Nil on quiet days.
    let peakHour: Int?

    /// True if the day had any activity at all. Used to decide whether to
    /// show the card or silently hide it on a quiet day.
    var hasActivity: Bool {
        sessionCount > 0 && turnCount > 0
    }

    /// A zero-activity report for a given date. Useful when aggregating
    /// across a week and a given day had no JSONL entries at all.
    static func empty(date: Date) -> DailyReport {
        DailyReport(
            date: date,
            sessionCount: 0,
            turnCount: 0,
            focusMinutes: 0,
            toolCounts: [:],
            skillCounts: [:],
            mcpServerCounts: [:],
            linesWritten: 0,
            primaryProjectName: nil,
            projectCount: 0,
            peakBurstMinutes: 0,
            filesEdited: 0,
            peakHour: nil
        )
    }
}

// MARK: - Weekly aggregate

/// Rolled-up stats across 7 daily reports, used by the "week" view. Some
/// fields are sums, some are maxes, some are unions — see comments.
struct WeeklyReport: Equatable, Sendable, Codable {
    /// The 7 daily reports this week covers, oldest → newest. `last` is
    /// "yesterday". Always exactly 7 entries, padded with `.empty` for
    /// quiet days so the sparkline layout stays stable.
    let days: [DailyReport]

    let turnCount: Int           // sum
    let focusMinutes: Int         // sum
    let linesWritten: Int         // sum
    let sessionCount: Int         // sum — distinct sessions per day are summed,
                                  // not globally deduped (a session that spans
                                  // two days counts twice; rare).
    let filesEdited: Int          // sum (approximation — no cross-day dedupe)
    let projectCount: Int         // union size across the 7 days
    let toolCounts: [String: Int]        // merged sum
    let skillCounts: [String: Int]        // merged sum
    let mcpServerCounts: [String: Int]    // merged sum

    /// Longest single focus burst over the whole week, plus which day it
    /// happened on (for the "peak focus happened on Wednesday" highlight).
    let peakBurstMinutes: Int
    let peakBurstDate: Date?

    /// The single day with the most user turns over the week.
    let peakDay: DailyReport?

    /// The project that had the most turns over the whole week.
    let primaryProjectName: String?

    /// Number of consecutive days with activity ending on `days.last`.
    /// 0 if yesterday itself had no activity.
    let streak: Int

    var hasActivity: Bool { turnCount > 0 }

    /// Build a weekly aggregate from 7 daily reports. Assumes `days` is
    /// already in chronological order.
    static func aggregate(_ days: [DailyReport]) -> WeeklyReport {
        let turns = days.reduce(0) { $0 + $1.turnCount }
        let focus = days.reduce(0) { $0 + $1.focusMinutes }
        let lines = days.reduce(0) { $0 + $1.linesWritten }
        let sessions = days.reduce(0) { $0 + $1.sessionCount }
        let files = days.reduce(0) { $0 + $1.filesEdited }

        var tools: [String: Int] = [:]
        var skills: [String: Int] = [:]
        var mcps: [String: Int] = [:]
        var projectTurnSum: [String: Int] = [:]
        var allProjects = Set<String>()
        var peakBurst = 0
        var peakBurstDate: Date?
        var peakDay: DailyReport?

        for d in days {
            for (k, v) in d.toolCounts  { tools[k, default: 0] += v }
            for (k, v) in d.skillCounts { skills[k, default: 0] += v }
            for (k, v) in d.mcpServerCounts { mcps[k, default: 0] += v }
            if let p = d.primaryProjectName {
                projectTurnSum[p, default: 0] += d.turnCount
                allProjects.insert(p)
            }
            if d.peakBurstMinutes > peakBurst {
                peakBurst = d.peakBurstMinutes
                peakBurstDate = d.date
            }
            if peakDay == nil || d.turnCount > (peakDay?.turnCount ?? 0) {
                peakDay = d
            }
        }

        // Streak: count trailing consecutive active days from the end.
        var streak = 0
        for d in days.reversed() {
            if d.hasActivity { streak += 1 } else { break }
        }

        return WeeklyReport(
            days: days,
            turnCount: turns,
            focusMinutes: focus,
            linesWritten: lines,
            sessionCount: sessions,
            filesEdited: files,
            projectCount: allProjects.count,
            toolCounts: tools,
            skillCounts: skills,
            mcpServerCounts: mcps,
            peakBurstMinutes: peakBurst,
            peakBurstDate: peakBurstDate,
            peakDay: (peakDay?.hasActivity == true) ? peakDay : nil,
            primaryProjectName: projectTurnSum.max { $0.value < $1.value }?.key,
            streak: streak
        )
    }
}
