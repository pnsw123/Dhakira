import Foundation

struct DetectedDate {
    let date: Date
    let range: Range<String.Index>
}

final class DateDetectionService {
    private let detector: NSDataDetector?

    init() {
        detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    }

    func detectDates(in text: String) -> [DetectedDate] {
        guard let detector = detector else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: nsRange)
        return matches.compactMap { match in
            guard let date = match.date,
                  let range = Range(match.range, in: text) else { return nil }
            return DetectedDate(date: date, range: range)
        }
    }
}
