import Foundation

public enum TailscaleState: Equatable, Sendable {
    case connected, notConnected, connecting, needsLogin, notInstalled

    public var text: String {
        switch self {
        case .connected: "Connected"
        case .notConnected: "Not connected"
        case .connecting: "Connecting…"
        case .needsLogin: "Log in needed"
        case .notInstalled: "Tailscale isn't installed"
        }
    }
}

public struct TailscaleDevice: Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var ipv4: String?
    public var isOnline: Bool
    public var isSelf: Bool

    public init(id: String, name: String, ipv4: String?, isOnline: Bool, isSelf: Bool) {
        self.id = id; self.name = name; self.ipv4 = ipv4; self.isOnline = isOnline; self.isSelf = isSelf
    }
}

/// What `tailscale status --json` says, reduced to what the tab shows.
public struct TailscaleStatus: Equatable, Sendable {
    public var state: TailscaleState
    public var devices: [TailscaleDevice]

    public init(state: TailscaleState, devices: [TailscaleDevice]) {
        self.state = state
        self.devices = devices
    }

    /// Nil when the output isn't a JSON object.
    public static func parse(_ json: Data) -> TailscaleStatus? {
        guard let root = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return nil }
        var devices: [TailscaleDevice] = []
        if let me = root["Self"] as? [String: Any] { devices.append(device(id: "self", me, isSelf: true)) }
        for (key, value) in root["Peer"] as? [String: Any] ?? [:] {
            if let peer = value as? [String: Any] { devices.append(device(id: key, peer, isSelf: false)) }
        }
        devices.sort { a, b in
            if a.isSelf != b.isSelf { return a.isSelf }
            if a.isOnline != b.isOnline { return a.isOnline }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return TailscaleStatus(state: state(root["BackendState"] as? String), devices: devices)
    }

    private static func state(_ backend: String?) -> TailscaleState {
        switch backend {
        case "Running": .connected
        case "Starting": .connecting
        case "NeedsLogin", "NeedsMachineAuth": .needsLogin
        default: .notConnected
        }
    }

    private static func device(id: String, _ d: [String: Any], isSelf: Bool) -> TailscaleDevice {
        var name = d["HostName"] as? String ?? ""
        if name.isEmpty {
            name = (d["DNSName"] as? String)?.split(separator: ".").first.map(String.init) ?? ""
        }
        let ips = d["TailscaleIPs"] as? [String] ?? []
        return TailscaleDevice(id: id, name: name.isEmpty ? "Unknown" : name,
                               ipv4: ips.first { $0.contains(".") },
                               isOnline: d["Online"] as? Bool ?? false, isSelf: isSelf)
    }
}
