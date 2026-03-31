import Foundation
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "DateDetection")

struct DetectedDate {
    let date: Date
    let range: Range<String.Index>
}

final class DateDetectionService {
    private let detector: NSDataDetector?

    // MARK: - Static normalisation tables (compiled once, reused across calls)

    /// One regex that tokenises a string into alphanumeric words.
    /// `static let` means it is compiled exactly once for the app's lifetime.
    private static let tokenRegex: NSRegularExpression =
        try! NSRegularExpression(pattern: #"[A-Za-z0-9]+"#)

    /// Flat map from lowercase slang / abbreviation → standard English.
    /// All keys are lowercased; lookup is done on `token.lowercased()` so
    /// "MO", "Mo", and "mo" all resolve correctly.
    private static let slangMap: [String: String] = [
        // tomorrow
        "tmrw": "tomorrow",   "tmrrow": "tomorrow",  "tmr": "tomorrow",
        "tmro": "tomorrow",   "tomo": "tomorrow",    "tomoro": "tomorrow",
        "2morrow": "tomorrow","2mrw": "tomorrow",    "2moro": "tomorrow",
        "2mrow": "tomorrow",  "2mro": "tomorrow",
        // today
        "2day": "today",  "2dy": "today",  "tdy": "today",  "tod": "today",
        // tonight
        "2nite": "tonight",  "tonite": "tonight",  "tnite": "tonight",
        "2night": "tonight", "tn": "tonight",
        // night
        "nite": "night",
        // next / this
        "nxt": "next",  "dis": "this",
        // weekdays — 3-letter
        "mon": "Monday",  "tue": "Tuesday",  "wed": "Wednesday",
        "thu": "Thursday","fri": "Friday",   "sat": "Saturday",  "sun": "Sunday",
        // weekdays — 2-letter ISO / calendar-app style
        "mo": "Monday",  "tu": "Tuesday",  "we": "Wednesday",
        "th": "Thursday","fr": "Friday",   "sa": "Saturday",   "su": "Sunday",
        // months
        "janu": "January",  "feb": "February",  "mar": "March",
        "apr": "April",     "jun": "June",      "jul": "July",
        "aug": "August",    "sep": "September", "oct": "October",
        "nov": "November",  "dec": "December",
    ]

    init() {
        do {
            detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            log.info("DateDetectionService: NSDataDetector initialised successfully")
        } catch {
            log.error("DateDetectionService: failed to create NSDataDetector — \(error.localizedDescription)")
            detector = nil
        }
    }

    // MARK: - Public API

    func detectDates(in text: String) -> [DetectedDate] {
        guard let detector = detector else {
            log.error("detectDates: detector unavailable — returning empty")
            return []
        }
        let normalized = normalize(text)
        log.debug("detectDates: original='\(text)' normalized='\(normalized)'")
        let nsRange = NSRange(normalized.startIndex..., in: normalized)
        let matches = detector.matches(in: normalized, options: [], range: nsRange)
        let results = matches.compactMap { match -> DetectedDate? in
            guard let date = match.date else { return nil }
            // Map the range back to the *original* string best-effort:
            // use the full string range so CalendarSyncService can still strip
            // the date token.  A nil range here would skip stripping, which is
            // safer than a crash on mis-mapped indices.
            let range = Range(match.range, in: normalized).flatMap { normRange -> Range<String.Index>? in
                // Try to find the same substring in the original text so the
                // stripping logic in CalendarSyncService works on the right text.
                let token = String(normalized[normRange])
                return text.range(of: token, options: .caseInsensitive)
            } ?? text.startIndex..<text.startIndex   // fallback: empty range at start
            return DetectedDate(date: date, range: range)
        }
        log.info("detectDates: found \(results.count) date(s)")
        return results
    }

    // MARK: - Normalization

    /// Converts informal / abbreviated date-time text into forms NSDataDetector
    /// understands.  Covers abbreviations, slang, relative durations, alternate
    /// separators, and 2-digit years.
    func normalize(_ text: String) -> String {
        var s = text

        // ── 1. Token-dictionary word substitution ────────────────────────────
        // One tokenizer regex finds all alphanumeric words; O(1) dict lookup
        // per token.  Iterating in reverse keeps NSRange values valid after
        // each in-place replacement.
        let fullNSRange = NSRange(s.startIndex..., in: s)
        let tokenMatches = DateDetectionService.tokenRegex
            .matches(in: s, options: [], range: fullNSRange)
        for match in tokenMatches.reversed() {
            let token = (s as NSString).substring(with: match.range).lowercased()
            if let replacement = DateDetectionService.slangMap[token] {
                s = (s as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }

        // ── 1b. Context-sensitive replacements (cannot go in slangMap) ───────
        // "noon" / "midnight" get "at " prepended only when not already there.
        s = s.replacingOccurrences(of: #"(?i)(?<!\bat )\bnoon\b"#,
                                   with: "at noon", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?i)(?<!\bat )\bmidnight\b"#,
                                   with: "at midnight", options: .regularExpression)

        // ── 2. "@" as "at" before a time ─────────────────────────────────────
        // "dentist @5pm" → "dentist at 5pm"
        s = s.replacingOccurrences(of: #"@\s*(\d)"#, with: "at $1", options: .regularExpression)

        // ── 3. Compact time formats ───────────────────────────────────────────
        // "5p" → "5pm",  "5a" → "5am"  (single-letter am/pm suffix)
        s = s.replacingOccurrences(of: #"(?i)\b(\d{1,2})(p)\b"#, with: "$1pm", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?i)\b(\d{1,2})(a)\b"#, with: "$1am", options: .regularExpression)

        // ── 4. Relative durations → absolute date strings ────────────────────
        // "in 2 hours", "in 30 min", "in 30m", "in 2h", "in an hour", "in a minute"
        s = expandRelativeDurations(in: s)

        // ── 5. Comma-separated dates → slashes ───────────────────────────────
        // "3,31,2026"  →  "3/31/2026"
        // Match digits-comma-digits-comma-digits only (avoid normal prose commas)
        s = s.replacingOccurrences(of: #"\b(\d{1,2}),(\d{1,2}),(\d{2,4})\b"#, with: "$1/$2/$3", options: .regularExpression)

        // ── 6. Dot-separated dates → slashes ─────────────────────────────────
        // "31.3.26"  →  "31/3/2026"   (also handles "3.31.2026")
        s = expandDotDates(in: s)

        // ── 7. Dash-separated dates that NSDataDetector misses ────────────────
        // "31-3-26" → "31/3/2026"
        s = expandDashDates(in: s)

        // ── 8. Two-digit years → four-digit ──────────────────────────────────
        // "3/31/26" → "3/31/2026"  (only for years 00-99 that look like years)
        s = expandTwoDigitYears(in: s)

        // ── 9. Two-part numeric dates (no year) → zero-padded MM/DD/YYYY ─────
        // "04-04" / "4-4" / "4.4" / "4/4" → "04/04/2026"
        // NSDataDetector only reliably parses zero-padded slash dates without a year.
        s = expandTwoPartDates(in: s)

        log.debug("normalize: '\(text)' → '\(s)'")
        return s
    }

    // MARK: - Private helpers

    /// Replaces "in N hours/minutes/seconds" with an absolute date-time string.
    private func expandRelativeDurations(in text: String) -> String {
        var result = text
        let now = Date()
        let cal = Calendar.current

        // Pattern: "in <number|a|an> <unit>"
        // Units: h, hr, hrs, hour, hours, m, min, mins, minute, minutes, s, sec, secs, second, seconds
        let pattern = #"(?i)\bin\s+(a\s+|an\s+)?(\d+(?:\.\d+)?)\s*(h|hr|hrs|hour|hours|m|min|mins|minute|minutes|s|sec|secs|second|seconds)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }

        // Also handle "in an hour", "in a minute"
        let wordPattern = #"(?i)\bin\s+(an?\s+)(hour|minute|second)s?\b"#
        if let wRegex = try? NSRegularExpression(pattern: wordPattern) {
            let matches = wRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let unitRange = Range(match.range(at: 2), in: result) else { continue }
                let unit = String(result[unitRange]).lowercased()
                var component: Calendar.Component = .hour
                var amount = 1
                switch unit {
                case "hour": component = .hour; amount = 1
                case "minute": component = .minute; amount = 1
                case "second": component = .second; amount = 1
                default: break
                }
                if let future = cal.date(byAdding: component, value: amount, to: now) {
                    let replacement = formatAbsolute(future)
                    let nsMatchRange = match.range
                    result = (result as NSString).replacingCharacters(in: nsMatchRange, with: replacement)
                }
            }
        }

        // Numeric form: "in 2 hours", "in 30min"
        let numMatches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in numMatches.reversed() {
            guard let numRange  = Range(match.range(at: 2), in: result),
                  let unitRange = Range(match.range(at: 3), in: result) else { continue }
            let amount = Double(result[numRange]) ?? 1
            let unit   = String(result[unitRange]).lowercased()
            var seconds: Double = 0
            switch unit {
            case "h", "hr", "hrs", "hour", "hours":   seconds = amount * 3600
            case "m", "min", "mins", "minute", "minutes": seconds = amount * 60
            case "s", "sec", "secs", "second", "seconds": seconds = amount
            default: break
            }
            if seconds > 0 {
                let future = now.addingTimeInterval(seconds)
                let replacement = formatAbsolute(future)
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        return result
    }

    /// Formats a Date as "March 30 2026 at 5:30 PM" so NSDataDetector parses it reliably.
    private func formatAbsolute(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d yyyy 'at' h:mm a"
        return fmt.string(from: date)
    }

    /// Expands dot-separated dates: "31.3.26" → "31/3/2026", "3.31.2026" → "3/31/2026"
    private func expandDotDates(in text: String) -> String {
        let pattern = #"\b(\d{1,2})\.(\d{1,2})\.(\d{2,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let r1 = Range(match.range(at: 1), in: result),
                  let r2 = Range(match.range(at: 2), in: result),
                  let r3 = Range(match.range(at: 3), in: result) else { continue }
            let p1 = String(result[r1])
            let p2 = String(result[r2])
            var p3 = String(result[r3])
            if p3.count == 2 { p3 = expandYear(p3) }
            result = result.replacingCharacters(in: Range(match.range, in: result)!, with: "\(p1)/\(p2)/\(p3)")
        }
        return result
    }

    /// Expands dash-separated dates that look like DD-MM-YY(YY): "31-3-26" → "31/3/2026"
    private func expandDashDates(in text: String) -> String {
        let pattern = #"\b(\d{1,2})-(\d{1,2})-(\d{2,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let r1 = Range(match.range(at: 1), in: result),
                  let r2 = Range(match.range(at: 2), in: result),
                  let r3 = Range(match.range(at: 3), in: result) else { continue }
            let p1 = String(result[r1])
            let p2 = String(result[r2])
            var p3 = String(result[r3])
            if p3.count == 2 { p3 = expandYear(p3) }
            result = result.replacingCharacters(in: Range(match.range, in: result)!, with: "\(p1)/\(p2)/\(p3)")
        }
        return result
    }

    /// Expands two-digit years in slash-separated dates: "3/31/26" → "3/31/2026"
    private func expandTwoDigitYears(in text: String) -> String {
        let pattern = #"\b(\d{1,2})/(\d{1,2})/(\d{2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let r3 = Range(match.range(at: 3), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }
            let yearStr = String(result[r3])
            let expanded = expandYear(yearStr)
            if expanded != yearStr {
                let full = String(result[fullRange])
                let newFull = full.dropLast(2) + expanded
                result = result.replacingCharacters(in: fullRange, with: newFull)
            }
        }
        return result
    }

    /// Converts a 2-digit year string to 4-digit: "26" → "2026", "99" → "1999"
    private func expandYear(_ twoDigit: String) -> String {
        guard let yy = Int(twoDigit) else { return twoDigit }
        let full = yy <= 49 ? 2000 + yy : 1900 + yy
        return String(full)
    }

    /// Converts 2-part numeric dates (no year) into zero-padded MM/DD/YYYY.
    ///
    /// NSDataDetector only reliably parses dates without a year when they are
    /// zero-padded with slashes: "04/04" works, "4/4" / "04-04" / "4.4" do not.
    ///
    /// This function catches all separators (-, ., /) and single-digit variants,
    /// validates that both parts are in plausible month/day ranges, pads them,
    /// infers the year (current year if the date is still ahead, otherwise next
    /// year), and produces "MM/DD/YYYY".
    private func expandTwoPartDates(in text: String) -> String {
        // Match M-D, MM-DD, M.D, MM.DD, M/D, MM/DD  — NOT already 3-part (year present)
        // The negative lookahead (?!\d) ensures we don't re-match already-expanded dates.
        let pattern = #"\b(\d{1,2})([-./])(\d{1,2})\b(?![-./]\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let cal = Calendar.current
        let now  = Date()
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let r1 = Range(match.range(at: 1), in: result),
                  let r3 = Range(match.range(at: 3), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }
            let p1 = Int(result[r1]) ?? 0   // month candidate
            let p2 = Int(result[r3]) ?? 0   // day candidate
            // Validate: month 1-12, day 1-31
            guard (1...12).contains(p1), (1...31).contains(p2) else { continue }
            // Infer year: use current year, roll to next if that date has passed.
            var comps = DateComponents(month: p1, day: p2)
            let currentYear = cal.component(.year, from: now)
            comps.year = currentYear
            let candidate = cal.date(from: comps) ?? now
            let year = candidate < now ? currentYear + 1 : currentYear
            // Produce zero-padded MM/DD/YYYY
            let expanded = String(format: "%02d/%02d/%04d", p1, p2, year)
            result = result.replacingCharacters(in: fullRange, with: expanded)
        }
        return result
    }
}
