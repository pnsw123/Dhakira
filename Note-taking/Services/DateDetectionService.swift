import Foundation
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "DateDetection")

struct DetectedDate {
    let date: Date
    let range: Range<String.Index>
}

final class DateDetectionService {
    private let detector: NSDataDetector?

    init() {
        do {
            detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
            log.info("DateDetectionService: NSDataDetector initialised successfully")
        } catch {
            log.error("DateDetectionService: failed to create NSDataDetector — \(error.localizedDescription)")
            detector = nil
        }
    }

    func detectDates(in text: String) -> [DetectedDate] {
        guard let detector = detector else {
            log.error("detectDates: detector unavailable — returning empty")
            return []
        }
        log.debug("detectDates: scanning \(text.count) chars")
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: nsRange)
        let results = matches.compactMap { match -> DetectedDate? in
            guard let date = match.date,
                  let range = Range(match.range, in: text) else { return nil }
            return DetectedDate(date: date, range: range)
        }
        log.info("detectDates: found \(results.count) date(s) in text")
        return results
    }
}
