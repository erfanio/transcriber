import Foundation

/// Counts characters the way they take up space on screen: combining marks,
/// ZWNJ (very common in Persian), bidi controls and other format characters count as zero.
public enum TextMeasure {
    public static func visibleCount(_ text: String) -> Int {
        var count = 0
        for character in text {
            let isInvisible = character.unicodeScalars.allSatisfy { isZeroWidth($0) }
            if !isInvisible { count += 1 }
        }
        return count
    }

    static func isZeroWidth(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .enclosingMark, .format:
            return true
        default:
            return false
        }
    }
}
