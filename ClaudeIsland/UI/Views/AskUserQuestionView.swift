//
//  AskUserQuestionView.swift
//  ClaudeIsland
//
//  Interactive UI for answering AskUserQuestion prompts from Claude Code.
//  Sends the selected option index to the terminal via AppleScript / cmux.
//

import SwiftUI

struct AskUserQuestionView: View {
    let session: SessionState
    let context: QuestionContext
    @ObservedObject var sessionMonitor: ClaudeSessionMonitor
    @State private var customText: String = ""
    @State private var hoveredIndex: Int? = nil
    @State private var isSending: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(session.projectName)
                    .notchFont(11, weight: .semibold)
                    .notchSecondaryForeground()
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Questions + options
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(context.questions.enumerated()), id: \.offset) { _, question in
                        questionBlock(question: question)
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer(minLength: 4)

            // Custom text input
            customInputBar
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            // Jump to terminal — bottom, full width
            jumpToTerminalButton
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Question Block

    @ViewBuilder
    private func questionBlock(question: QuestionItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question.question)
                .notchFont(12, weight: .semibold)
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 2)

            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                optionRow(index: index + 1, option: option, optionCount: question.options.count)
            }
        }
    }

    private func optionRow(index: Int, option: QuestionOption, optionCount: Int) -> some View {
        Button {
            guard !isSending else { return }
            isSending = true
            DebugLogger.log("AskUser", "Option \(index) tapped: \(option.label)")
            Task { await approveAndSendOption(index: index) }
        } label: {
            HStack(spacing: 8) {
                Text("\(index)")
                    .notchFont(10, weight: .bold)
                    .foregroundColor(TerminalColors.amber)
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(TerminalColors.amber.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(option.label)
                        .notchFont(11, weight: .medium)
                        .foregroundColor(.white.opacity(0.85))

                    if let desc = option.description, !desc.isEmpty {
                        Text(desc)
                            .notchFont(9, weight: .regular)
                            .foregroundColor(.white.opacity(0.35))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .notchFont(8)
                    .foregroundColor(.white.opacity(hoveredIndex == index ? 0.5 : 0.15))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hoveredIndex == index ? TerminalColors.amber.opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                hoveredIndex == index ? TerminalColors.amber.opacity(0.2) : Color.white.opacity(0.06),
                                lineWidth: 0.5
                            )
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredIndex = isHovered ? index : nil
        }
    }

    // MARK: - Custom Input

    private var customInputBar: some View {
        HStack(spacing: 6) {
            TextField("Type your answer...", text: $customText)
                .textFieldStyle(.plain)
                .notchFont(11)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
                .onSubmit { submitCustomText() }

            Button {
                submitCustomText()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(
                        customText.isEmpty || isSending
                            ? Color.white.opacity(0.15)
                            : TerminalColors.amber
                    )
            }
            .buttonStyle(.plain)
            .disabled(customText.isEmpty || isSending)
        }
    }

    // MARK: - Jump to Terminal

    private var jumpToTerminalButton: some View {
        Button {
            Task { await TerminalJumper.shared.jump(to: session) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .notchFont(10)
                Text("Jump to Terminal")
                    .notchFont(10, weight: .medium)
            }
            .foregroundColor(.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Terminal Sending

    /// Send the option number directly to the terminal where Claude Code's
    /// AskUserQuestion UI is waiting for input.
    private func approveAndSendOption(index: Int) async {
        await sendToTerminal("\(index)")
    }

    private func submitCustomText() {
        guard !customText.isEmpty, !isSending else { return }
        isSending = true
        let text = customText
        let optionCount = context.questions.first?.options.count ?? 0
        DebugLogger.log("AskUser", "Custom text: \(text)")
        Task {
            // Send "Other" option (last + 1), then the text
            await sendToTerminal("\(optionCount + 1)")
            try? await Task.sleep(nanoseconds: 500_000_000)
            await sendToTerminal(text)
        }
    }

    /// Send text to the terminal using CGEvent keyboard simulation.
    /// CGEvent posts at the HID level — same as physical keyboard input.
    /// This works with Claude Code's raw terminal mode (ink/React CLI).
    /// Code Island already has HID permissions for CGEvent (cursor fix).
    private func sendToTerminal(_ text: String) async {
        // First, jump to the correct terminal
        await TerminalJumper.shared.jump(to: session)
        // Wait for the terminal to become frontmost
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Type each character via CGEvent
        let src = CGEventSource(stateID: .hidSystemState)
        for char in text {
            if let keyCode = Self.keyCodeForChar(char) {
                let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode.code, keyDown: true)
                if keyCode.shift { down?.flags = .maskShift }
                down?.post(tap: .cghidEventTap)

                let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode.code, keyDown: false)
                up?.post(tap: .cghidEventTap)
            }
        }

        // Press Return
        let returnDown = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: true)
        returnDown?.post(tap: .cghidEventTap)
        let returnUp = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: false)
        returnUp?.post(tap: .cghidEventTap)

        DebugLogger.log("AskUser", "Sent '\(text)' via CGEvent keystroke")
    }

    private struct KeyCode {
        let code: CGKeyCode
        let shift: Bool
    }

    private static func keyCodeForChar(_ char: Character) -> KeyCode? {
        // Map common characters to macOS virtual key codes
        switch char {
        case "1": return KeyCode(code: 18, shift: false)
        case "2": return KeyCode(code: 19, shift: false)
        case "3": return KeyCode(code: 20, shift: false)
        case "4": return KeyCode(code: 21, shift: false)
        case "5": return KeyCode(code: 23, shift: false)
        case "6": return KeyCode(code: 22, shift: false)
        case "7": return KeyCode(code: 26, shift: false)
        case "8": return KeyCode(code: 28, shift: false)
        case "9": return KeyCode(code: 25, shift: false)
        case "0": return KeyCode(code: 29, shift: false)
        case " ": return KeyCode(code: 49, shift: false)
        default:
            // For any other character, use CGEvent's unicode input
            return nil
        }
    }

    private func runAppleScript(_ script: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
