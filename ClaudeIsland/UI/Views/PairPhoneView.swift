//
//  PairPhoneView.swift
//  ClaudeIsland
//
//  QR code pairing button in settings menu + floating QR window.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Menu Row (inside NotchMenuView)

struct PairPhoneRow: View {
    @ObservedObject var syncManager = SyncManager.shared
    @State private var isHovered = false

    var body: some View {
        Button {
            QRPairingWindow.shared.show()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(isHovered ? 1 : 0.6))
                    .frame(width: 16)

                Text("Pair iPhone")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(isHovered ? 1 : 0.7))

                Spacer()

                if syncManager.isEnabled {
                    HStack(spacing: 3) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Online")
                            .font(.system(size: 9))
                            .foregroundColor(.green.opacity(0.7))
                    }
                } else {
                    Image(systemName: "qrcode")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Floating QR Window

@MainActor
final class QRPairingWindow {
    static let shared = QRPairingWindow()

    private var window: NSWindow?

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = QRPairingContentView {
            self.close()
        }

        let hostingView = NSHostingView(rootView: contentView)
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.backgroundColor = .clear
        w.isMovableByWindowBackground = true
        w.contentView = hostingView
        w.center()
        w.level = .floating
        w.makeKeyAndOrderFront(nil)
        w.isReleasedWhenClosed = false

        self.window = w
    }

    func close() {
        window?.close()
        window = nil
    }
}

// MARK: - QR Content View

private struct QRPairingContentView: View {
    let onClose: () -> Void
    @State private var qrImage: NSImage?
    @State private var deviceName = Host.current().localizedName ?? "Mac"

    private var serverUrl: String {
        SyncManager.shared.serverUrl ?? "https://island.wdao.chat"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 36))
                    .foregroundStyle(.linearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text("Pair with CodeLight")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text("Scan this QR code with your iPhone")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            // QR Code
            if let qrImage {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                    )
                    .shadow(color: .cyan.opacity(0.3), radius: 20)
            }

            // Info
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 10))
                    Text(serverUrl)
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.4))

                HStack(spacing: 4) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 10))
                    Text(deviceName)
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 320, height: 420)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: NSColor(white: 0.12, alpha: 1)))
        )
        .onAppear {
            generateQRCode()
        }
    }

    private func generateQRCode() {
        let payload: [String: String] = [
            "s": serverUrl,
            "k": "",
            "n": deviceName,
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(jsonString.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return }

        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: scale)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return }

        qrImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
