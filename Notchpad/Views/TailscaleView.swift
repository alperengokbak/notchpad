import AppKit
import NotchpadCore
import SwiftUI

/// The Tailscale tab: status, one button, and the device list.
struct TailscaleView: View {
    let status: TailscaleStatus?
    let busy: Bool
    let message: String?
    let copiedDeviceID: String?
    let onConnect: (Bool) -> Void
    let onCopy: (TailscaleDevice) -> Void

    private var state: TailscaleState? { status?.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(state == .connected ? Color.green : Color(white: 0.4)).frame(width: 8, height: 8)
                Text(message ?? state?.text ?? " ").font(.system(size: 13, weight: .semibold))
                Spacer()
                actionButton
            }
            .frame(height: 24)
            if state != .notInstalled, let devices = status?.devices, !devices.isEmpty {
                Rectangle().fill(Color(white: 0.12)).frame(height: 1)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(devices) { row($0) }
                    }
                }
            }
        }
    }

    @ViewBuilder private var actionButton: some View {
        if busy {
            ProgressView().controlSize(.small).frame(width: 80)
        } else {
            switch state {
            case .connected: pill("Disconnect") { onConnect(false) }
            case .notConnected, .connecting: pill("Connect") { onConnect(true) }
            case .needsLogin: pill("Open Tailscale") { openTailscale() }
            case .notInstalled, nil: EmptyView()
            }
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.black)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Capsule().fill(Color.white)).contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func row(_ d: TailscaleDevice) -> some View {
        Button { onCopy(d) } label: {
            HStack(spacing: 8) {
                Circle()
                    .strokeBorder(d.isOnline ? Color.clear : Color(white: 0.45), lineWidth: 1.2)
                    .background(Circle().fill(d.isOnline ? Color.green : Color.clear))
                    .frame(width: 7, height: 7)
                Text(d.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Spacer(minLength: 8)
                if copiedDeviceID == d.id {
                    Text("Copied").font(.system(size: 11, weight: .semibold)).foregroundStyle(.green)
                } else {
                    Text(d.ipv4 ?? "").font(.system(size: 12).monospacedDigit()).foregroundStyle(Color(white: 0.6))
                }
                Text(d.isSelf ? "this Mac" : (d.isOnline ? "" : "offline"))
                    .font(.system(size: 10)).foregroundStyle(Color(white: 0.5)).frame(width: 48, alignment: .trailing)
            }
            .padding(.vertical, 3).padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(d.ipv4 == nil)
    }

    private func openTailscale() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Tailscale.app"))
    }
}
