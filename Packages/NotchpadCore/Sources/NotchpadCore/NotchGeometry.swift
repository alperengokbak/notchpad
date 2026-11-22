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

    /// Width of the closed-notch strip: 70 pt for each thing it shows (focus timer, microphone).
    public static func wingWidth(focus: Bool, mic: Bool) -> CGFloat {
        CGFloat((focus ? 1 : 0) + (mic ? 1 : 0)) * 70
    }

    /// The black extension left of the notch that shows the focus countdown while closed.
    public static func wingRect(notch: CGRect, width: CGFloat = 70) -> CGRect {
        CGRect(x: notch.minX - width, y: notch.minY, width: width, height: notch.height)
    }

    /// Hot zone that also covers the countdown extension when it's showing.
    public static func hotZone(notch: CGRect, wing: CGRect?) -> CGRect {
        guard let wing else { return hotZone(notch: notch) }
        return hotZone(notch: notch.union(wing))
    }
}
