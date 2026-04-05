import Foundation
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "DateDetection")

struct DetectedDate {
    let date: Date
    /// Optional end date for time ranges like "5 to 8pm", "2-5pm".
    /// Nil means use the default duration (1 hour).
    let endDate: Date?
    let range: Range<String.Index>

    init(date: Date, range: Range<String.Index>, endDate: Date? = nil) {
        self.date = date
        self.endDate = endDate
        self.range = range
    }
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
        // time-of-day
        "morn": "morning",  "aft": "afternoon",  "eve": "evening",
        // next / this / coming / upcoming
        "nxt": "next",  "dis": "this",  "comin": "coming",  "upcomin": "upcoming",
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

        // Pre-extract time ranges ("5 to 8pm", "2-5pm", "9am-12pm") BEFORE normalization.
        // We store the duration so we can attach endDate to the result.
        let (textForNorm, extractedDuration) = extractTimeRange(from: text)

        let normalized = normalize(textForNorm)
        log.debug("detectDates: original='\(text)' normalized='\(normalized)' duration=\(extractedDuration.map { "\($0)s" } ?? "default")")
        let nsRange = NSRange(normalized.startIndex..., in: normalized)
        let matches = detector.matches(in: normalized, options: [], range: nsRange)
        let results = matches.compactMap { match -> DetectedDate? in
            guard let date = match.date else { return nil }
            let range = Range(match.range, in: normalized).flatMap { normRange -> Range<String.Index>? in
                let token = String(normalized[normRange])
                return text.range(of: token, options: .caseInsensitive)
            } ?? text.startIndex..<text.startIndex
            let endDate = extractedDuration.map { date.addingTimeInterval($0) }
            return DetectedDate(date: date, range: range, endDate: endDate)
        }
        log.info("detectDates: found \(results.count) date(s)")
        return results
    }

    // MARK: - Time range extraction

    /// Extracts time ranges like "5 to 8pm", "2-5pm", "9am-12pm", "7 to 8:30pm"
    /// Returns the text with the range replaced by just the START time (so NSDataDetector
    /// can parse it), plus the duration in seconds.
    private func extractTimeRange(from text: String) -> (String, TimeInterval?) {
        // Patterns for time ranges — start time, separator, end time
        // "5 to 8pm", "5-8pm", "5pm to 8pm", "5pm-8pm", "9:30am to 12pm", "5 to 8 pm"
        let pattern = #"(?i)\b(\d{1,2}(?::\d{2})?)\s*(am|pm|a\.?m\.?|p\.?m\.?)?\s*(?:to|-|–|—|til|till|until)\s*(\d{1,2}(?::\d{2})?)\s*(am|pm|a\.?m\.?|p\.?m\.?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return (text, nil) }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard let match = matches.first, match.numberOfRanges >= 5 else { return (text, nil) }

        let startTimeStr = nsText.substring(with: match.range(at: 1))
        let startPeriodRange = match.range(at: 2)
        let startPeriod = startPeriodRange.location != NSNotFound ? nsText.substring(with: startPeriodRange) : nil
        let endTimeStr = nsText.substring(with: match.range(at: 3))
        let endPeriod = nsText.substring(with: match.range(at: 4))

        // Parse start and end hours/minutes
        let startComps = parseTimeComponents(startTimeStr)
        let endComps = parseTimeComponents(endTimeStr)
        let endIsPM = endPeriod.lowercased().hasPrefix("p")
        let endIsAM = endPeriod.lowercased().hasPrefix("a")

        // Determine start period: if not specified, infer from end period and logic
        // "5 to 8pm" → start is 5pm (same period), "9 to 12pm" → start is 9am (crosses noon)
        let startIsPM: Bool
        if let sp = startPeriod {
            startIsPM = sp.lowercased().hasPrefix("p")
        } else if endIsPM {
            // If start hour < end hour and both would be PM, keep PM
            // If start hour > end hour (e.g. "10 to 2pm"), start is AM
            startIsPM = startComps.hour <= endComps.hour || startComps.hour >= 12
        } else {
            startIsPM = false
        }

        var startHour24 = startComps.hour
        if startIsPM && startHour24 < 12 { startHour24 += 12 }
        if !startIsPM && startHour24 == 12 { startHour24 = 0 }

        var endHour24 = endComps.hour
        if endIsPM && endHour24 < 12 { endHour24 += 12 }
        if endIsAM && endHour24 == 12 { endHour24 = 0 }

        let startMinutes = startHour24 * 60 + startComps.minute
        let endMinutes = endHour24 * 60 + endComps.minute
        var durationMinutes = endMinutes - startMinutes
        if durationMinutes <= 0 { durationMinutes += 24 * 60 } // crosses midnight

        let duration = TimeInterval(durationMinutes * 60)
        log.debug("extractTimeRange: \(startTimeStr)\(startPeriod ?? "") to \(endTimeStr)\(endPeriod) → duration \(durationMinutes)min")

        // Replace the full range with just the start time for NSDataDetector
        let resolvedStartPeriod = startIsPM ? "pm" : "am"
        let replacement = "\(startTimeStr)\(startPeriod ?? resolvedStartPeriod)"
        let newText = nsText.replacingCharacters(in: match.range, with: replacement)
        return (newText, duration)
    }

    /// Parses "5" → (5, 0), "5:30" → (5, 30)
    private func parseTimeComponents(_ timeStr: String) -> (hour: Int, minute: Int) {
        let parts = timeStr.split(separator: ":")
        let hour = Int(parts[0]) ?? 0
        let minute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        return (hour, minute)
    }

    // MARK: - Normalization

    /// Converts informal / abbreviated date-time text into forms NSDataDetector
    /// understands.  Covers abbreviations, slang, relative durations, alternate
    /// separators, and 2-digit years.
    func normalize(_ text: String) -> String {
        var s = text

        // ── 0. Strip "due" before date phrases ──────────────────────────────
        // NSDataDetector misinterprets "due tomorrow" as TODAY (a known Apple bug).
        // Removing "due on/by/at/before" lets the actual date word parse correctly.
        s = s.replacingOccurrences(of: #"(?i)\bdue\s+(?:on|by|at|before|for)?\s*"#,
                                   with: "", options: .regularExpression)

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
        // "tonight" without a time → "today at 8pm" (a sensible evening default)
        // If user wrote "tonight at 9", the "at 9" will override via NSDataDetector.
        s = s.replacingOccurrences(of: #"(?i)\btonight\b(?!\s+at\b)"#,
                                   with: "today at 8pm", options: .regularExpression)

        // ── 2. "@" as "at" before a time ─────────────────────────────────────
        // "dentist @5pm" → "dentist at 5pm"
        s = s.replacingOccurrences(of: #"@\s*(\d)"#, with: "at $1", options: .regularExpression)

        // ── 3. Compact time formats ───────────────────────────────────────────
        // "5p" → "5pm",  "5a" → "5am"  (single-letter am/pm suffix)
        s = s.replacingOccurrences(of: #"(?i)\b(\d{1,2})(p)\b"#, with: "$1pm", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?i)\b(\d{1,2})(a)\b"#, with: "$1am", options: .regularExpression)

        // ── 4a. Relative day/week phrases → absolute date strings ────────────
        // "next week", "next day", "next Monday", "this Friday", etc.
        // NSDataDetector is unreliable with these, so we resolve them ourselves.
        s = expandRelativeDayPhrases(in: s)

        // ── 4b. Relative durations → absolute date strings ───────────────────
        // "in 2 hours", "in 30 min", "in 30m", "in 2h", "in an hour", "in a minute"
        s = expandRelativeDurations(in: s)

        // ── 4c. Reorder stranded TIME before DATE → DATE at TIME ─────────────
        // After expanding relative phrases, "at 9 pm next week" becomes
        // "at 9 pm April 10 2026" — NSDataDetector sees two separate dates.
        // Fix: move the time AFTER the date so it reads as one unit:
        // "April 10 2026 at 9 pm"
        s = reorderStrandedTimeBeforeDate(in: s)

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

    /// Resolves relative day/week phrases that NSDataDetector misses:
    /// "next Monday", "next week", "next day", "this Friday", "coming Wednesday",
    /// "upcoming Friday", "day after tomorrow", bare weekday names, etc.
    ///
    /// Uses DATE-ONLY format so user-supplied times ("at 5pm") are preserved
    /// and picked up by NSDataDetector separately.
    private func expandRelativeDayPhrases(in text: String) -> String {
        var result = text
        let cal = Calendar.current
        let now = Date()

        let weekdayNames: [(String, Int)] = [
            ("sunday", 1), ("monday", 2), ("tuesday", 3), ("wednesday", 4),
            ("thursday", 5), ("friday", 6), ("saturday", 7),
        ]

        // Helper: nearest future occurrence of a weekday (1–7 days ahead)
        // Used for "this Friday", "coming Monday", bare "Friday", etc.
        func nearestOccurrence(of weekday: Int) -> Date? {
            let today = cal.component(.weekday, from: now)
            var daysAhead = weekday - today
            if daysAhead <= 0 { daysAhead += 7 }
            return cal.date(byAdding: .day, value: daysAhead, to: now)
        }

        // Helper: NEXT WEEK's occurrence of a weekday (8–14 days ahead)
        // Used for "next Friday", "next Monday" — always a week AFTER the nearest.
        func nextWeekOccurrence(of weekday: Int) -> Date? {
            let today = cal.component(.weekday, from: now)
            var daysAhead = weekday - today
            if daysAhead <= 0 { daysAhead += 7 }
            daysAhead += 7  // push to next week
            return cal.date(byAdding: .day, value: daysAhead, to: now)
        }

        // Helper: replace all matches of a pattern with an absolute date string
        func replacePattern(_ pattern: String, with date: Date, in text: inout String) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                let replacement = formatAbsoluteDateOnly(date)
                text = (text as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }

        // ── "next next <weekday>" → TWO weeks out (15–21 days ahead) ────────
        // Must run BEFORE "next <weekday>" to avoid partial matching.
        for (name, weekday) in weekdayNames {
            let pattern = "(?i)\\bnext\\s+next\\s+\(name)\\b"
            let today = cal.component(.weekday, from: now)
            var daysAhead = weekday - today
            if daysAhead <= 0 { daysAhead += 7 }
            daysAhead += 14  // two weeks out
            if let target = cal.date(byAdding: .day, value: daysAhead, to: now) {
                replacePattern(pattern, with: target, in: &result)
            }
        }

        // ── "next next week" → 14 days from now ─────────────────────────────
        if let target = cal.date(byAdding: .day, value: 14, to: now) {
            replacePattern(#"(?i)\bnext\s+next\s+week\b"#, with: target, in: &result)
        }

        // ── "next <weekday>" → NEXT WEEK's instance (8–14 days ahead) ──────
        for (name, weekday) in weekdayNames {
            let pattern = "(?i)\\bnext\\s+\(name)\\b"
            if let target = nextWeekOccurrence(of: weekday) {
                replacePattern(pattern, with: target, in: &result)
            }
        }

        // ── "this/coming/upcoming <weekday>" → nearest instance (1–7 days) ──
        for (name, weekday) in weekdayNames {
            let pattern = "(?i)\\b(?:this|coming|upcoming)\\s+\(name)\\b"
            if let target = nearestOccurrence(of: weekday) {
                replacePattern(pattern, with: target, in: &result)
            }
        }

        // ── bare weekday name (just "Monday" without prefix) → nearest ───────
        for (name, weekday) in weekdayNames {
            let pattern = "(?i)(?<!next\\s)(?<!coming\\s)(?<!upcoming\\s)(?<!this\\s)(?<!every\\s)(?<!each\\s)(?<!last\\s)\\b\(name)\\b"
            if let target = nearestOccurrence(of: weekday) {
                replacePattern(pattern, with: target, in: &result)
            }
        }

        // ── "next weekend" → next Saturday ───────────────────────────────────
        if let target = nearestOccurrence(of: 7) { // Saturday = 7
            replacePattern(#"(?i)\b(?:next|coming|upcoming)\s+weekend\b"#, with: target, in: &result)
        }

        // ── "this weekend" → this/next Saturday ──────────────────────────────
        if let target = nearestOccurrence(of: 7) {
            replacePattern(#"(?i)\bthis\s+weekend\b"#, with: target, in: &result)
        }

        // ── "next week" → 7 days from now ────────────────────────────────────
        if let target = cal.date(byAdding: .day, value: 7, to: now) {
            replacePattern(#"(?i)\bnext\s+week\b"#, with: target, in: &result)
        }

        // ── "next day" → tomorrow ────────────────────────────────────────────
        if let target = cal.date(byAdding: .day, value: 1, to: now) {
            replacePattern(#"(?i)\bnext\s+day\b"#, with: target, in: &result)
        }

        // ── "day after tomorrow" ─────────────────────────────────────────────
        if let target = cal.date(byAdding: .day, value: 2, to: now) {
            replacePattern(#"(?i)\bday\s+after\s+tomorrow\b"#, with: target, in: &result)
        }

        // ── "next month" → same day, next month ─────────────────────────────
        if let target = cal.date(byAdding: .month, value: 1, to: now) {
            replacePattern(#"(?i)\bnext\s+month\b"#, with: target, in: &result)
        }

        // ── "next year" → same day, next year ────────────────────────────────
        if let target = cal.date(byAdding: .year, value: 1, to: now) {
            replacePattern(#"(?i)\bnext\s+year\b"#, with: target, in: &result)
        }

        // ── "end of day" / "EOD" / "later today" → today at 5:00 PM ─────────
        if var eod = cal.date(bySettingHour: 17, minute: 0, second: 0, of: now) {
            // If it's already past 5 PM, push to 11:59 PM
            if eod <= now { eod = cal.date(bySettingHour: 23, minute: 59, second: 0, of: now) ?? eod }
            replacePatternWithTime(#"(?i)\b(?:end\s+of\s+(?:the\s+)?day|EOD)\b"#, with: eod, in: &result)
            replacePatternWithTime(#"(?i)\blater\s+today\b"#, with: eod, in: &result)
        }

        // ── "end of week" / "EOW" → this Friday at 5:00 PM ──────────────────
        if let friday = nearestOccurrence(of: 6) { // Friday = 6
            let fridayEOD = cal.date(bySettingHour: 17, minute: 0, second: 0, of: friday) ?? friday
            replacePatternWithTime(#"(?i)\b(?:end\s+of\s+(?:the\s+)?week|EOW)\b"#, with: fridayEOD, in: &result)
        }

        // ── "end of month" / "EOM" → last day of current month ──────────────
        if let endOfMonth = cal.date(byAdding: DateComponents(month: 1, day: -1),
                                     to: cal.date(from: cal.dateComponents([.year, .month], from: now))!) {
            let eom = cal.date(bySettingHour: 17, minute: 0, second: 0, of: endOfMonth) ?? endOfMonth
            replacePatternWithTime(#"(?i)\b(?:end\s+of\s+(?:the\s+)?month|EOM)\b"#, with: eom, in: &result)
        }

        return result
    }

    /// Replace matches with a full date+time string (for phrases where the time is inherent,
    /// like "end of day" = 5 PM — we don't want the user to have to add "at 5pm").
    private func replacePatternWithTime(_ pattern: String, with date: Date, in text: inout String) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            let replacement = formatAbsolute(date)
            text = (text as NSString).replacingCharacters(in: match.range, with: replacement)
        }
    }

    /// Replaces "in N hours/minutes/seconds/days/weeks/months/years" with an absolute date-time string.
    private func expandRelativeDurations(in text: String) -> String {
        var result = text
        let now = Date()
        let cal = Calendar.current

        // ── Word form: "in a day", "in an hour", "in a week", "in a month", "in a year" ──
        let wordPattern = #"(?i)\bin\s+(an?\s+)(hour|minute|second|day|week|month|year|fortnight)s?\b"#
        if let wRegex = try? NSRegularExpression(pattern: wordPattern) {
            let matches = wRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let unitRange = Range(match.range(at: 2), in: result) else { continue }
                let unit = String(result[unitRange]).lowercased()
                var component: Calendar.Component = .hour
                var amount = 1
                switch unit {
                case "hour":      component = .hour;   amount = 1
                case "minute":    component = .minute;  amount = 1
                case "second":    component = .second;  amount = 1
                case "day":       component = .day;     amount = 1
                case "week":      component = .day;     amount = 7
                case "fortnight": component = .day;     amount = 14
                case "month":     component = .month;   amount = 1
                case "year":      component = .year;    amount = 1
                default: break
                }
                if let future = cal.date(byAdding: component, value: amount, to: now) {
                    // Use date-only for day+ units, date+time for sub-day units
                    let useDateOnly = ["day", "week", "fortnight", "month", "year"].contains(unit)
                    let replacement = useDateOnly ? formatAbsoluteDateOnly(future) : formatAbsolute(future)
                    result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
                }
            }
        }

        // ── Numeric form: "in 2 hours", "in 30min", "in 3 days", "in 2 weeks", "in 6 months" ──
        let pattern = #"(?i)\bin\s+(\d+(?:\.\d+)?)\s*(h|hr|hrs|hour|hours|m|min|mins|minute|minutes|s|sec|secs|second|seconds|d|day|days|w|wk|wks|week|weeks|mo|mos|month|months|y|yr|yrs|year|years)\b"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let numMatches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in numMatches.reversed() {
                guard let numRange  = Range(match.range(at: 1), in: result),
                      let unitRange = Range(match.range(at: 2), in: result) else { continue }
                let amount = Double(result[numRange]) ?? 1
                let unit   = String(result[unitRange]).lowercased()

                var future: Date?
                var useDateOnly = false

                switch unit {
                case "h", "hr", "hrs", "hour", "hours":
                    future = now.addingTimeInterval(amount * 3600)
                case "m", "min", "mins", "minute", "minutes":
                    future = now.addingTimeInterval(amount * 60)
                case "s", "sec", "secs", "second", "seconds":
                    future = now.addingTimeInterval(amount)
                case "d", "day", "days":
                    future = cal.date(byAdding: .day, value: Int(amount), to: now)
                    useDateOnly = true
                case "w", "wk", "wks", "week", "weeks":
                    future = cal.date(byAdding: .day, value: Int(amount) * 7, to: now)
                    useDateOnly = true
                case "mo", "mos", "month", "months":
                    future = cal.date(byAdding: .month, value: Int(amount), to: now)
                    useDateOnly = true
                case "y", "yr", "yrs", "year", "years":
                    future = cal.date(byAdding: .year, value: Int(amount), to: now)
                    useDateOnly = true
                default: break
                }

                if let future {
                    let replacement = useDateOnly ? formatAbsoluteDateOnly(future) : formatAbsolute(future)
                    result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
                }
            }
        }

        return result
    }

    /// Fixes stranded time-before-date patterns produced by relative phrase expansion.
    ///
    /// After `expandRelativeDayPhrases`, input like "at 9 pm next week" becomes
    /// "at 9 pm April 10 2026".  NSDataDetector treats "9 pm" and "April 10 2026"
    /// as two independent dates (the first defaults to today).
    ///
    /// This function detects "TIME … DATE" and reorders to "DATE at TIME" so
    /// NSDataDetector reads them as a single date-time.
    ///
    /// Handles:  "at 9pm April 10 2026", "9:30 pm April 10 2026",
    ///           "at 9 pm 04/10/2026",  "9pm April 10 2026"
    private func reorderStrandedTimeBeforeDate(in text: String) -> String {
        // Month-name dates:  "April 10 2026"
        let monthDatePattern = #"(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}\s+\d{4}"#
        // Numeric dates:  "04/10/2026", "4-10-2026"
        let numericDatePattern = #"\d{1,2}[/\-]\d{1,2}[/\-]\d{4}"#
        // Time:  "9pm", "9:30 pm", "9 pm", "9:30pm"
        let timePattern = #"\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM|a\.m\.|p\.m\.)"#

        // Match: optional "at " + TIME + whitespace + DATE
        let fullPattern = "(?i)(?:at\\s+)?(\(timePattern))\\s+(\(monthDatePattern)|\(numericDatePattern))"

        guard let regex = try? NSRegularExpression(pattern: fullPattern) else { return text }
        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let timeRange = Range(match.range(at: 1), in: result),
                  let dateRange = Range(match.range(at: 2), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }
            let timePart = String(result[timeRange])
            let datePart = String(result[dateRange])
            result = result.replacingCharacters(in: fullRange, with: "\(datePart) at \(timePart)")
        }

        log.debug("reorderStrandedTimeBeforeDate: '\(text)' → '\(result)'")
        return result
    }

    /// Formats a Date as "March 30 2026 at 5:30 PM" so NSDataDetector parses it reliably.
    /// Used for duration-based replacements ("in 2 hours") where the time IS the point.
    private func formatAbsolute(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d yyyy 'at' h:mm a"
        return fmt.string(from: date)
    }

    /// Formats a Date as "March 30 2026" (date only, no time).
    /// Used for day-level replacements ("next Monday") so any user-supplied time
    /// ("at 5pm") remains intact and gets parsed by NSDataDetector separately.
    private func formatAbsoluteDateOnly(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d yyyy"
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
        // Match M/D, MM/DD, M.D, MM.DD  — NOT already 3-part (year present)
        // The negative lookahead (?!\d) ensures we don't re-match already-expanded dates.
        // IMPORTANT: Dashes are excluded because "8-9", "3-5", etc. are extremely common
        // in natural text (page ranges, item numbers, score notation) and would create
        // false-positive calendar events (Issue #108).
        let pattern = #"\b(\d{1,2})([./])(\d{1,2})\b(?![./]\d)"#
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
