//
//  NotchCustomizationSettingsView.swift
//  ClaudeIsland
//
//  Settings UI surface for the notch customization feature.
//  Exposes the theme picker, font-size segmented picker,
//  Show Buddy / Show Usage Bar toggles, Hardware Notch mode
//  picker, and the "Customize Size & Position…" entry button
//  that enters live edit mode.
//
//  Deviation from spec: the spec (Section 4.1) describes a new
//  "Notch" subsection inside the Appearance tab of
//  `SystemSettingsView`. CodeIsland does not currently have a
//  `SystemSettingsView` — settings live in the notch itself via
//  `NotchMenuView`. This view is intended to be embedded inside
//  the existing `NotchMenuView` settings stack as a drop-in block,
//  matching the surrounding visual style (dark translucent rows,
//  lime accent).
//
//  Spec: docs/superpowers/specs/2026-04-08-notch-customization-design.md
//  sections 4.1, 4.5, 4.6.
//

import SwiftUI

struct NotchCustomizationSettingsView: View {
    @ObservedObject private var store: NotchCustomizationStore = .shared

    private static let brandLime = Color(red: 0xD7/255, green: 0xFE/255, blue: 0x62/255)

    var body: some View {
        // Title is provided by the enclosing SettingsCard; no internal
        // section header needed.
        VStack(alignment: .leading, spacing: 4) {
            themeRow
            fontSizeRow
            toggleRow(
                label: L10n.notchShowBuddy,
                icon: "sparkles",
                isOn: store.customization.showBuddy
            ) {
                store.update { $0.showBuddy.toggle() }
            }
            .accessibilityLabel(L10n.notchShowBuddy)
            toggleRow(
                label: L10n.notchShowUsageBar,
                icon: "chart.bar",
                isOn: store.customization.showUsageBar
            ) {
                store.update { $0.showUsageBar.toggle() }
            }
            .accessibilityLabel(L10n.notchShowUsageBar)
            hardwareModeRow
            customizeButton
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.25))
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Theme picker

    private var themeRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "paintpalette")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 12)
            Text(L10n.notchTheme)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.85))
            Spacer(minLength: 0)
            Menu {
                ForEach(NotchThemeID.allCases) { id in
                    Button {
                        store.update { $0.theme = id }
                    } label: {
                        Label {
                            Text(L10n.notchThemeName(id))
                        } icon: {
                            // Swatch for the menu item — decorative.
                            Circle().fill(NotchPalette.for(id).bg)
                        }
                        .accessibilityLabel("\(L10n.notchThemeName(id)) theme")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(NotchPalette.for(store.customization.theme).bg)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Text(L10n.notchThemeName(store.customization.theme))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(L10n.notchTheme)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }

    // MARK: - Font size segmented picker

    private var fontSizeRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "textformat.size")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 12)
            Text(L10n.notchFontSize)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.85))
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                fontSizeSegment(.small,   shortLabel: L10n.notchFontSmall,   accessibilityLabel: L10n.notchFontSmallFull)
                fontSizeSegment(.default, shortLabel: L10n.notchFontDefault, accessibilityLabel: L10n.notchFontDefaultFull)
                fontSizeSegment(.large,   shortLabel: L10n.notchFontLarge,   accessibilityLabel: L10n.notchFontLargeFull)
                fontSizeSegment(.xLarge,  shortLabel: L10n.notchFontXLarge,  accessibilityLabel: L10n.notchFontXLargeFull)
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06)))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }

    private func fontSizeSegment(
        _ scale: FontScale,
        shortLabel: String,
        accessibilityLabel: String
    ) -> some View {
        Button {
            store.update { $0.fontScale = scale }
        } label: {
            Text(shortLabel)
                .font(.system(size: 9, weight: store.customization.fontScale == scale ? .bold : .regular))
                .foregroundColor(store.customization.fontScale == scale ? .black : .white.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(store.customization.fontScale == scale ? Self.brandLime : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Toggle row

    private func toggleRow(
        label: String,
        icon: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(isOn ? 0.85 : 0.5))
                    .frame(width: 12)
                Text(label)
                    .font(.system(size: 10, weight: isOn ? .semibold : .regular))
                    .foregroundColor(.white.opacity(isOn ? 0.95 : 0.7))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Circle()
                    .fill(isOn ? Self.brandLime : Color.white.opacity(0.2))
                    .frame(width: 5, height: 5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOn ? Self.brandLime.opacity(0.08) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isOn ? Self.brandLime.opacity(0.25) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hardware mode

    private var hardwareModeRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 12)
            Text(L10n.notchHardwareMode)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.85))
            Spacer(minLength: 0)
            Menu {
                Button(L10n.notchHardwareAuto) {
                    store.update { $0.hardwareNotchMode = .auto }
                }
                Button(L10n.notchHardwareForceVirtual) {
                    store.update { $0.hardwareNotchMode = .forceVirtual }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(
                        store.customization.hardwareNotchMode == .auto
                            ? L10n.notchHardwareAuto
                            : L10n.notchHardwareForceVirtual
                    )
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(L10n.notchHardwareMode)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }

    // MARK: - Customize button

    private var customizeButton: some View {
        Button {
            store.enterEditMode()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10))
                Text(L10n.notchCustomizeButton)
                    .font(.system(size: 10, weight: .semibold))
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .opacity(0.7)
            }
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Self.brandLime.opacity(0.85))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.notchCustomizeButton)
        .accessibilityHint("Opens live edit mode for resizing and positioning the notch directly.")
    }
}
