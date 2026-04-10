import UIKit

// MARK: - HighlightApplier
// Single source of truth for applying highlight (.backgroundColor) to an
// NSMutableAttributedString.
//
// The bleed problem (and the fix):
// If you apply `.backgroundColor` to every character in a wrapping
// paragraph (letters AND inter-word spaces), TextKit treats the whole
// thing as one contiguous attribute run. Its background drawing path
// then extends each non-final visual line's background rect all the
// way to the text container's right edge — that's the bleed shown in
// the user's screenshot.
//
// If instead you skip ALL spaces, you avoid the bleed but lose the
// connected look between words on the same line. The user wants both:
// connected highlight within a visual line, and no bleed at the wrap.
//
// Strategy (two phases):
//   1. `applyBackground` — paint background on letters AND inter-word
//      spaces (so within-line spaces stay highlighted). Newlines and
//      checkbox attachments are skipped.
//   2. `trimWrapWhitespace` — after layout, walk every visual line and
//      strip `.backgroundColor` from the trailing whitespace of every
//      line. That breaks the contiguous attribute run exactly at the
//      wrap point, so the layout manager can no longer extend the
//      background rect to the line edge.
//
// Both functions are pure data transforms: no UIKit views needed.
// `trimWrapWhitespace` requires a laid-out NSLayoutManager + NSTextContainer
// pair, but it never reads from a UIView. That makes the whole module
// directly testable from XCTest.
enum HighlightApplier {

    // MARK: - Phase 1: paint

    /// Paint highlight `.backgroundColor` over every non-newline,
    /// non-attachment character in `range`. Inter-word spaces are
    /// included so the highlight looks connected within a line.
    /// Newlines and checkbox/image attachments are always skipped.
    static func applyBackground(_ color: UIColor,
                                to storage: NSMutableAttributedString,
                                range: NSRange) {
        guard range.length > 0 else { return }
        let safe = clamp(range, to: storage.length)
        guard safe.length > 0 else { return }

        let ns = storage.string as NSString
        storage.beginEditing()
        var i = safe.location
        let end = safe.location + safe.length
        while i < end {
            defer { i += 1 }
            // Skip attachments (checkboxes, images) — never coloured.
            if storage.attribute(.attachment, at: i, effectiveRange: nil) != nil {
                continue
            }
            let ch = ns.character(at: i)
            if isNewline(ch) { continue }
            storage.addAttribute(.backgroundColor,
                                 value: color,
                                 range: NSRange(location: i, length: 1))
        }
        storage.endEditing()
    }

    /// Remove all highlight background from `range` (no special rules).
    static func removeBackground(from storage: NSMutableAttributedString,
                                 range: NSRange) {
        let safe = clamp(range, to: storage.length)
        guard safe.length > 0 else { return }
        storage.beginEditing()
        storage.removeAttribute(.backgroundColor, range: safe)
        storage.endEditing()
    }

    // MARK: - Phase 2: trim wrap-point whitespace

    /// Walk every visual line in the laid-out text and strip
    /// `.backgroundColor` from the trailing whitespace character of each
    /// line. This is the anti-bleed step: by removing the attribute at
    /// the wrap point, the contiguous background run is broken there,
    /// and TextKit no longer extends the background rect to the right
    /// edge of the text container on that line.
    ///
    /// Must be called AFTER `applyBackground` AND after layout has been
    /// ensured for the container (`layoutManager.ensureLayout(for:)`).
    static func trimWrapWhitespace(in storage: NSMutableAttributedString,
                                   using layoutManager: NSLayoutManager,
                                   container: NSTextContainer) {
        layoutManager.ensureLayout(for: container)
        let glyphRange = layoutManager.glyphRange(for: container)
        guard glyphRange.length > 0 else { return }

        var trimRanges: [NSRange] = []
        let ns = storage.string as NSString

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, lineGlyphRange, _ in
            let charRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange,
                                                         actualGlyphRange: nil)
            guard charRange.length > 0 else { return }
            // Walk backwards from the end of the line and strip every
            // run of trailing whitespace (handles "word   " just as
            // safely as "word "). Stop at the first non-whitespace.
            var idx = charRange.location + charRange.length - 1
            while idx >= charRange.location {
                guard idx < storage.length else { idx -= 1; continue }
                let ch = ns.character(at: idx)
                if isInterWordSpace(ch) || isNewline(ch) {
                    trimRanges.append(NSRange(location: idx, length: 1))
                    idx -= 1
                } else {
                    break
                }
            }
        }

        guard !trimRanges.isEmpty else { return }
        storage.beginEditing()
        for r in trimRanges {
            storage.removeAttribute(.backgroundColor, range: r)
        }
        storage.endEditing()
    }

    // MARK: - Private

    private static func isInterWordSpace(_ ch: unichar) -> Bool {
        return ch == 0x20 || ch == 0x09 || ch == 0xA0
    }

    private static func isNewline(_ ch: unichar) -> Bool {
        return ch == 0x0A || ch == 0x0D || ch == 0x2028 || ch == 0x2029
    }

    private static func clamp(_ r: NSRange, to length: Int) -> NSRange {
        let loc = min(max(r.location, 0), length)
        let len = min(r.length, length - loc)
        return NSRange(location: loc, length: max(0, len))
    }
}
