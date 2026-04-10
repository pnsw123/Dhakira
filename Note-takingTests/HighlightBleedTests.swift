import XCTest
import UIKit
@testable import Note_taking

// MARK: - HighlightBleedTests
// Regression guard for the highlight-bleed bug AND the highlight-gap
// regression that came with the first fix attempt.
//
// Two requirements that must hold simultaneously:
//   A. NO BLEED — on a wrapped paragraph, the highlight rect on each
//      visual line must end at the rightmost glyph, not at the text
//      container's right edge.
//   B. NO GAPS — inter-word spaces on the same visual line must be
//      highlighted, so the highlight looks connected within a line.
//
// The implementation strategy:
//   1. paint .backgroundColor on letters AND inter-word spaces
//   2. then walk visual lines and strip the trailing whitespace of
//      each line, breaking the contiguous run at the wrap point.

final class HighlightBleedTests: XCTestCase {

    private let containerWidth: CGFloat = 220
    private let paragraphText =
        "you need to redesign every screenshot to make it catchy. " +
        "your marketing strategy depends on the final presentation quality."
    private let highlightBG = UIColor(red: 0.35, green: 0.05, blue: 0.05, alpha: 1.0)

    // MARK: - Helpers

    private func makeAttributed(_ text: String) -> NSMutableAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]
        return NSMutableAttributedString(string: text, attributes: attrs)
    }

    /// Build a TextKit 1 stack on top of an existing attributed string.
    /// The returned NSTextStorage is the LIVE storage — mutate it (not
    /// the original input) when you want layout to follow your edits.
    private func makeStack(for attributed: NSAttributedString)
        -> (storage: NSTextStorage, layout: NSLayoutManager, container: NSTextContainer)
    {
        let storage = NSTextStorage(attributedString: attributed)
        let layout  = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: containerWidth,
                                                     height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.delegate = HighlightLayoutManagerDelegate.shared
        layout.ensureLayout(for: container)
        return (storage, layout, container)
    }

    /// Apply highlight using the SAME two-phase production sequence:
    /// paint, then trim wrap-point whitespace once layout is built.
    /// Returns the live storage that was actually highlighted.
    private func applyProductionHighlight(_ bg: UIColor,
                                          to text: String,
                                          range: NSRange? = nil)
        -> (storage: NSTextStorage, layout: NSLayoutManager, container: NSTextContainer)
    {
        let attributed = makeAttributed(text)
        let stack = makeStack(for: attributed)
        let r = range ?? NSRange(location: 0, length: stack.storage.length)
        HighlightApplier.applyBackground(bg, to: stack.storage, range: r)
        HighlightApplier.trimWrapWhitespace(in: stack.storage,
                                            using: stack.layout,
                                            container: stack.container)
        return stack
    }

    /// Render check using `enumerateEnclosingRects`, the same TextKit
    /// path that `drawBackground` walks. If any rect for a
    /// `.backgroundColor` run extends past the rightmost glyph on its
    /// visual line we have bleed.
    private func rectsBleed(in ts: NSAttributedString,
                            stack: (storage: NSTextStorage, layout: NSLayoutManager, container: NSTextContainer))
        -> Bool
    {
        let layout = stack.layout
        let container = stack.container
        let tolerance: CGFloat = 2.0

        var lineMaxX: [(yMin: CGFloat, yMax: CGFloat, rightX: CGFloat)] = []
        let fullGlyphRange = layout.glyphRange(for: container)
        layout.enumerateLineFragments(forGlyphRange: fullGlyphRange) { _, usedRect, _, _, _ in
            lineMaxX.append((usedRect.minY, usedRect.maxY, usedRect.maxX))
        }

        var searchLoc = 0
        let totalLen = ts.length
        while searchLoc < totalLen {
            var effective = NSRange()
            let value = ts.attribute(.backgroundColor,
                                     at: searchLoc,
                                     longestEffectiveRange: &effective,
                                     in: NSRange(location: searchLoc, length: totalLen - searchLoc))
            if value != nil {
                let runGlyphRange = layout.glyphRange(forCharacterRange: effective,
                                                      actualCharacterRange: nil)
                var bleed = false
                layout.enumerateEnclosingRects(
                    forGlyphRange: runGlyphRange,
                    withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                    in: container
                ) { rect, stop in
                    let mid = rect.midY
                    for line in lineMaxX {
                        if mid >= line.yMin - 0.5 && mid <= line.yMax + 0.5 {
                            if rect.maxX > line.rightX + tolerance {
                                bleed = true
                                stop.pointee = true
                            }
                            break
                        }
                    }
                }
                if bleed { return true }
            }
            searchLoc = effective.location + max(effective.length, 1)
        }
        return false
    }

    // MARK: - Requirement A: NO BLEED

    /// Production two-phase pipeline must NOT bleed past glyphs on
    /// any wrapped visual line.
    func testProductionPipelineDoesNotBleedOnWrappedParagraph() {
        let stack = applyProductionHighlight(highlightBG, to: paragraphText)
        XCTAssertFalse(rectsBleed(in: stack.storage, stack: stack),
            "Highlight bleed: a background rect extended past the rightmost " +
            "glyph on a wrapped visual line.")
    }

    /// Sanity check: paragraph must actually wrap to multiple visual
    /// lines under our test container width, otherwise the bleed test
    /// is meaningless.
    func testParagraphActuallyWrapsUnderTestWidth() {
        let stack = applyProductionHighlight(highlightBG, to: paragraphText)
        var lineCount = 0
        let glyphRange = stack.layout.glyphRange(for: stack.container)
        stack.layout.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, _, _ in
            lineCount += 1
        }
        XCTAssertGreaterThan(lineCount, 2,
            "Test paragraph must wrap to >2 visual lines for the bleed test to be meaningful.")
    }

    // MARK: - Requirement B: NO GAPS WITHIN A LINE

    /// At least one inter-word space SOMEWHERE in the highlighted
    /// paragraph must still carry `.backgroundColor` after trimming —
    /// otherwise we regressed to the gappy-highlight behaviour the
    /// user complained about in the second screenshot.
    func testInterWordSpacesStayHighlightedWithinLines() {
        let stack = applyProductionHighlight(highlightBG, to: paragraphText)
        let ns = stack.storage.string as NSString
        var highlightedSpaceCount = 0
        for i in 0..<stack.storage.length {
            let ch = ns.character(at: i)
            guard ch == 0x20 else { continue }
            if stack.storage.attribute(.backgroundColor, at: i, effectiveRange: nil) != nil {
                highlightedSpaceCount += 1
            }
        }
        XCTAssertGreaterThanOrEqual(highlightedSpaceCount, 5,
            "Inter-word spaces should stay highlighted within visual lines so the " +
            "highlight looks connected. Found only \(highlightedSpaceCount) highlighted spaces.")
    }

    /// Strong version of B: For every visual line that has at least
    /// two words, the spaces BETWEEN those words on that line must be
    /// highlighted.
    func testEverySpaceBetweenTwoWordsOnSameVisualLineIsHighlighted() {
        let stack = applyProductionHighlight(highlightBG, to: paragraphText)
        let ns = stack.storage.string as NSString
        let layout = stack.layout
        let container = stack.container

        let glyphRange = layout.glyphRange(for: container)
        layout.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, lineGlyphs, _ in
            let lineChars = layout.characterRange(forGlyphRange: lineGlyphs, actualGlyphRange: nil)
            guard lineChars.length >= 3 else { return }
            // Trailing whitespace is allowed to be unhighlighted (that's
            // the whole point of the trim phase). Anything BEFORE the
            // last non-whitespace char of the line must be highlighted
            // if it's a space.
            var lastNonWS = -1
            for i in stride(from: lineChars.location + lineChars.length - 1,
                            through: lineChars.location, by: -1) {
                let ch = ns.character(at: i)
                if ch != 0x20 && ch != 0x09 && ch != 0xA0 && ch != 0x0A && ch != 0x0D {
                    lastNonWS = i
                    break
                }
            }
            guard lastNonWS > lineChars.location else { return }
            for i in lineChars.location..<lastNonWS {
                let ch = ns.character(at: i)
                guard ch == 0x20 else { continue }
                let bg = stack.storage.attribute(.backgroundColor, at: i, effectiveRange: nil)
                XCTAssertNotNil(bg,
                    "Inter-word space at \(i) on visual line \(lineChars) should be highlighted.")
            }
        }
    }

    // MARK: - Requirement C: edges (newlines, attachments)

    /// Newlines must NEVER receive `.backgroundColor` — otherwise blank
    /// lines fill in.
    func testNewlinesAreNeverHighlighted() {
        let stack = applyProductionHighlight(highlightBG, to: "alpha\nbeta\ngamma")
        let ns = stack.storage.string as NSString
        for i in 0..<stack.storage.length where ns.character(at: i) == 0x0A {
            let bg = stack.storage.attribute(.backgroundColor, at: i, effectiveRange: nil)
            XCTAssertNil(bg, "Newline at \(i) must not be highlighted.")
        }
    }

    /// A blank line between two paragraphs must remain entirely free
    /// of background.
    func testBlankLineBetweenParagraphsStaysClean() {
        let stack = applyProductionHighlight(highlightBG, to: "first paragraph\n\nsecond paragraph here")
        let ns = stack.storage.string as NSString
        for i in 0..<stack.storage.length {
            let ch = ns.character(at: i)
            if ch == 0x0A {
                let bg = stack.storage.attribute(.backgroundColor, at: i, effectiveRange: nil)
                XCTAssertNil(bg)
            }
        }
    }

    // MARK: - Requirement D: adversarial — short text, single word, two highlights

    /// Highlighting a single word that does NOT wrap must just paint
    /// that word — no surrounding spaces, no bleed.
    func testSingleWordHighlightDoesNotBleed() {
        let attributed = makeAttributed(paragraphText)
        let stack = makeStack(for: attributed)
        let target = (paragraphText as NSString).range(of: "marketing")
        XCTAssertNotEqual(target.location, NSNotFound)
        HighlightApplier.applyBackground(highlightBG, to: stack.storage, range: target)
        HighlightApplier.trimWrapWhitespace(in: stack.storage, using: stack.layout, container: stack.container)

        let ns = stack.storage.string as NSString
        for i in 0..<stack.storage.length where ns.character(at: i) == 0x20 {
            // Spaces OUTSIDE the targeted word must not be highlighted.
            if i >= target.location && i < target.location + target.length { continue }
            let bg = stack.storage.attribute(.backgroundColor, at: i, effectiveRange: nil)
            XCTAssertNil(bg, "Space at \(i) outside the target word must not be highlighted.")
        }
        XCTAssertFalse(rectsBleed(in: stack.storage, stack: stack))
    }

    /// Two separate highlighted words in the same wrapped paragraph
    /// must not bleed and must not highlight the gap between them.
    func testTwoSeparateHighlightsStayDisjointAndNoBleed() {
        let attributed = makeAttributed(paragraphText)
        let stack = makeStack(for: attributed)
        let a = (paragraphText as NSString).range(of: "redesign")
        let b = (paragraphText as NSString).range(of: "strategy")
        HighlightApplier.applyBackground(highlightBG, to: stack.storage, range: a)
        HighlightApplier.applyBackground(highlightBG, to: stack.storage, range: b)
        HighlightApplier.trimWrapWhitespace(in: stack.storage, using: stack.layout, container: stack.container)

        let gapIdx = a.location + a.length
        let bg = stack.storage.attribute(.backgroundColor, at: gapIdx, effectiveRange: nil)
        XCTAssertNil(bg, "Space between two separately-highlighted words must stay clean.")
        XCTAssertFalse(rectsBleed(in: stack.storage, stack: stack))
    }

    /// Short text that fits on a single line must highlight every
    /// inter-word space.
    func testShortSingleLineHighlightFillsAllSpaces() {
        let text = "hello world"
        let stack = applyProductionHighlight(highlightBG, to: text)
        let ns = stack.storage.string as NSString
        let spaceIdx = (text as NSString).range(of: " ").location
        let bg = stack.storage.attribute(.backgroundColor, at: spaceIdx, effectiveRange: nil)
        XCTAssertNotNil(bg, "Inter-word space on a single-line highlight must be highlighted.")
        // And the trailing-space removal logic shouldn't strip it because
        // there is no trailing space at the line end.
        XCTAssertEqual(ns.character(at: stack.storage.length - 1), unichar(("d" as Character).asciiValue!))
        XCTAssertFalse(rectsBleed(in: stack.storage, stack: stack))
    }

    // MARK: - Requirement E: meta-test — confirm bleed check is sensitive

    /// Sanity check: if you SKIP the trim phase, the bleed check must
    /// fire. If this stops failing, the bleed check is no longer
    /// sensitive and the suite must be repaired.
    func testBleedCheckFiresWhenTrimPhaseIsSkipped() {
        let attributed = makeAttributed(paragraphText)
        let stack = makeStack(for: attributed)
        HighlightApplier.applyBackground(highlightBG, to: stack.storage,
                                          range: NSRange(location: 0, length: stack.storage.length))
        // NOTE: deliberately NOT calling trimWrapWhitespace.
        XCTAssertTrue(rectsBleed(in: stack.storage, stack: stack),
            "Meta-test failure: bleed check did not detect bleed when the trim " +
            "phase was skipped. The check is no longer sensitive.")
    }
}
