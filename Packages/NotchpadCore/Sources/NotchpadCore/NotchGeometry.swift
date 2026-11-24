import CoreGraphics

/// What we need to know about a screen to find its notch. AppKit coordinates (origin bottom-left).
public struct ScreenMetrics: Equatable, Sendable {
    public var frame: CGRect
    public var leftAuxWidth: CGFloat?
    public var rightAuxWidth: CGFloat?
    public var safeTop: CGFloat

    public init(frame: CGRect, leftAuxWidth: CGFloat?, rightAuxWidth: CGFloat?, safeTop: CGFloat) {
        self.frame = frame
        self.leftAuxWidth = leftAuxWidth
        self.rightAuxWidth = rightAuxWidth
        self.safeTop = safeTop
    }
}

public enum NotchGeometry {
    /// Size of the open panel (layout A2).
    public static let openSize = CGSize(width: 680, height: 200)

    /// The notch, or nil when the screen has none.
    public static func notchRect(_ m: ScreenMetrics) -> CGRect? {
        guard m.safeTop > 0, let left = m.leftAuxWidth, let right = m.rightAuxWidth else { return nil }
        let width = m.frame.width - left - right
        guard width > 0 else { return nil }
        return CGRect(x: m.frame.minX + left, y: m.frame.maxY - m.safeTop, width: width, height: m.safeTop)
    }

    /// The open panel: centred under the notch, top edge on the top of the screen, kept on screen.
    public static func openRect(notch: CGRect, screen: CGRect, size: CGSize = openSize) -> CGRect {
        var x = notch.midX - size.width / 2
        x = min(max(x, screen.minX), screen.maxX - size.width)
        return CGRect(x: x, y: screen.maxY - size.height, width: size.width, height: size.height)
    }

    /// Where hovering opens the closed panel: the notch plus 10 pt left, right and below.
    public static func hotZone(notch: CGRect) -> CGRect {
        CGRect(x: notch.minX - 10, y: notch.minY - 10, width: notch.width + 20, height: notch.height + 10)
    }

    /// The black extensions beside the closed notch. Left: focus countdown and microphone (70 pt each),
    /// then the song's cover (36 pt). Right: the music bars (36 pt).
    /// `charging`: the "plugged in" badge (70 pt) shown for a few seconds right of the notch.
    public static func wings(focus: Bool, mic: Bool, music: Bool, charging: Bool = false) -> WingWidths {
        let left = CGFloat((focus ? 1 : 0) + (mic ? 1 : 0)) * 70 + (music ? 36 : 0)
        return WingWidths(left: left, right: (music ? 36 : 0) + (charging ? 70 : 0))
    }

    /// Hot zone that also covers the wings when they're showing.
    public static func hotZone(notch: CGRect, wings: WingWidths) -> CGRect {
        hotZone(notch: CGRect(x: notch.minX - wings.left, y: notch.minY,
                              width: notch.width + wings.left + wings.right, height: notch.height))
    }
}

/// Widths of the black extensions left and right of the closed notch.
public struct WingWidths: Equatable, Sendable {
    public var left: CGFloat
    public var right: CGFloat

    public init(left: CGFloat, right: CGFloat) {
        self.left = left
        self.right = right
    }
}
