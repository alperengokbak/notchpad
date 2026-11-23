import Foundation

/// Where the tab pills (and the + button) go in the strips beside the notch.
public struct TabStripSlots: Equatable, Sendable {
    public var mids: [CGFloat]
    public var widths: [CGFloat]
    public var plusMid: CGFloat?
}

public enum TabStripLayout {
    /// Fills the left strip first and continues in the right strip. If anything would run past
    /// the right end, every pill shrinks a little and is placed again, so nothing sits under the
    /// edit buttons or another pill.
    public static func place(widths natural: [CGFloat], leftStart: CGFloat, leftEnd: CGFloat,
                             rightStart: CGFloat, rightEnd: CGFloat, plusWidth: CGFloat,
                             plusIsOptional: Bool = false, spacing: CGFloat) -> TabStripSlots {
        var scale: CGFloat = 1
        var slots = attempt(natural, leftStart, leftEnd, rightStart, rightEnd, plusWidth, plusIsOptional, spacing)
        while slots == nil, scale > 0.3 {
            scale *= 0.95
            slots = attempt(natural.map { $0 * scale }, leftStart, leftEnd, rightStart, rightEnd, plusWidth, plusIsOptional, spacing)
        }
        return slots ?? attempt(natural.map { $0 * scale }, leftStart, leftEnd, rightStart, .infinity, plusWidth, plusIsOptional, spacing)!
    }

    /// One greedy pass; nil when something ends past `rightEnd`.
    private static func attempt(_ widths: [CGFloat], _ leftStart: CGFloat, _ leftEnd: CGFloat,
                                _ rightStart: CGFloat, _ rightEnd: CGFloat, _ plusWidth: CGFloat,
                                _ plusIsOptional: Bool, _ spacing: CGFloat) -> TabStripSlots? {
        var mids: [CGFloat] = []
        var x = leftStart
        var onRight = false
        func fit(_ w: CGFloat) -> CGFloat? {
            if !onRight, x + w > leftEnd { onRight = true; x = rightStart }
            guard x + w <= rightEnd + 0.001 else { return nil }
            defer { x += w + spacing }
            return x + w / 2
        }
        for w in widths {
            guard let mid = fit(w) else { return nil }
            mids.append(mid)
        }
        var plus: CGFloat?
        if plusWidth > 0 {
            // An optional + (greyed out at the tab limit) only shows if it fits; it never shrinks the tabs.
            let mid = fit(plusWidth)
            if mid == nil && !plusIsOptional { return nil }
            plus = mid
        }
        return TabStripSlots(mids: mids, widths: widths, plusMid: plus)
    }
}
