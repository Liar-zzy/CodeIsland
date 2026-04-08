//
//  Ext+NSScreen.swift
//  ClaudeIsland
//
//  Extensions for NSScreen to detect notch and built-in display
//

import AppKit

extension NSScreen {
    /// Returns the size of the notch on this screen (pixel-perfect using macOS APIs)
    var notchSize: CGSize {
        // 有刘海的屏幕：用 auxiliaryTopLeftArea/Right 精确计算
        if safeAreaInsets.top > 0 {
            let notchHeight = safeAreaInsets.top
            let fullWidth = frame.width
            let leftPadding = auxiliaryTopLeftArea?.width ?? 0
            let rightPadding = auxiliaryTopRightArea?.width ?? 0

            if leftPadding > 0, rightPadding > 0 {
                // +4 to match boring.notch's calculation for proper alignment
                let notchWidth = fullWidth - leftPadding - rightPadding + 4
                return CGSize(width: notchWidth, height: notchHeight)
            }
            return CGSize(width: 180, height: notchHeight)
        }

        // 无刘海屏幕：用 visibleFrame 推算实际 menu bar 高度
        let menuBarHeight = frame.height - visibleFrame.height - (visibleFrame.origin.y - frame.origin.y)
        let clampedHeight = max(24, min(menuBarHeight, 32))
        // 宽度按屏幕比例缩放，保持视觉一致
        let baseWidth: CGFloat = 200
        let scaleFactor = min(frame.width / 1440.0, 1.2)
        let width = baseWidth * scaleFactor

        return CGSize(width: width, height: clampedHeight)
    }

    /// Whether this is the built-in display
    var isBuiltinDisplay: Bool {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(screenNumber) != 0
    }

    /// The built-in display (with notch on newer MacBooks)
    static var builtin: NSScreen? {
        if let builtin = screens.first(where: { $0.isBuiltinDisplay }) {
            return builtin
        }
        return NSScreen.main
    }

    /// Whether this screen has a physical notch (camera housing)
    var hasPhysicalNotch: Bool {
        safeAreaInsets.top > 0
    }
}
