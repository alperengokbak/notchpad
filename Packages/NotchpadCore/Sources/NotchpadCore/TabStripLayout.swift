import Foundation

/// Where the tab pills (and the + button) go in the strips beside the notch.
public struct TabStripSlots: Equatable, Sendable {
    public var mids: [CGFloat]
    public var widths: [CGFloat]
    public var plusMid: CGFloat?
}

public enum TabStripLayout {
    /// Spare padding a pill can give up before its name gets cut (pills are name + 20, names need + 8).
    public static let sparePadding: CGFloat = 12
    /// Narrowest a pill gets before the tabs are allowed to continue right of the notch.
    public static let minWidth: CGFloat = 36

    /// Keeps the tabs together left of the notch, one after another, with the + right after the last.
    /// When they don't fit, the pills first give up spare padding, then shrink (names get cut).
    /// Only if even that fails do they continue right of the notch (the old two-sided layout).
    public static func place(widths natural: [CGFloat], leftStart: CGFloat, leftEnd: CGFloat,
                             rightStart: CGFloat, rightEnd: CGFloat, plusWidth: CGFloat,
                             plusIsOptional: Bool = false, spacing: CGFloat) -> TabStripSlots {
        let mandatoryPlus = plusWidth > 0 && !plusIsOptional
        if let widths = fitLeft(natural, length: leftEnd - leftStart,
                                reserved: mandatoryPlus ? plusWidth + spacing : 0, spacing: spacing) {
            var mids: [CGFloat] = []
            var x = leftStart
            for w in widths {
                mids.append(x + w / 2)
                x += w + spacing
            }
            var plus: CGFloat?
            // Right after the last tab. An optional (greyed, at the tab limit) + that doesn't fit there
            // is left out rather than shown across the notch; tabs never shrink for it.
            if plusWidth > 0, x + plusWidth <= leftEnd + 0.001 {
                plus = x + plusWidth / 2
            }
            return TabStripSlots(mids: mids, widths: widths, plusMid: plus)
        }
        return twoSided(natural, leftStart: leftStart, leftEnd: leftEnd, rightStart: rightStart, rightEnd: rightEnd,
                        plusWidth: plusWidth, plusIsOptional: plusIsOptional, spacing: spacing)
    }

    /// Widths that fit `length` side by side (after `reserved` space), or nil.
    private static func fitLeft(_ natural: [CGFloat], length: CGFloat, reserved: CGFloat, spacing: CGFloat) -> [CGFloat]? {
        guard !natural.isEmpty else { return [] }
        let room = length - reserved - spacing * CGFloat(natural.count - 1)
        let sum = natural.reduce(0, +)
        if sum <= room + 0.001 { return natural }
        // 1. Give up spare padding, the same amount for every pill.
        let trim = min(sparePadding, (sum - room) / CGFloat(natural.count))
        var widths = natural.map { $0 - trim }
        if widths.reduce(0, +) <= room + 0.001 { return widths }
        // 2. Shrink in proportion, never below minWidth: pills that hit the floor stay there
        //    and the others share what's left.
        guard minWidth * CGFloat(widths.count) <= room + 0.001 else { return nil }
        var floored = Set<Int>()
        while true {
            let free = widths.indices.filter { !floored.contains($0) }
            let freeSum = free.reduce(CGFloat(0)) { $0 + widths[$1] }
            let scale = (room - minWidth * CGFloat(floored.count)) / freeSum
            let newlyFloored = free.filter { widths[$0] * scale < minWidth }
            if newlyFloored.isEmpty {
                for i in free { widths[i] *= scale }
                for i in floored { widths[i] = minWidth }
                return widths
            }
            floored.formUnion(newlyFloored)
        }
    }

    /// Fills the left strip first and continues in the right strip. If anything would run past
    /// the right end, every pill shrinks a little and is placed again, so nothing sits under the
    /// edit buttons or another pill.
    private static func twoSided(_ natural: [CGFloat], leftStart: CGFloat, leftEnd: CGFloat,
                                 rightStart: CGFloat, rightEnd: CGFloat, plusWidth: CGFloat,
                                 plusIsOptional: Bool, spacing: CGFloat) -> TabStripSlots {
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
