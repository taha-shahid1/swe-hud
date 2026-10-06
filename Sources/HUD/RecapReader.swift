import Foundation

/// Latest `/recap` text (`away_summary` system record) in a session transcript.
/// Transcripts reach megabytes, so each call reads only the newly appended bytes.
final class RecapReader {
    struct Recap: Equatable {
        let text: String
        let at: Date
    }

    private var offsets: [URL: UInt64] = [:]
    private var latest: [URL: Recap] = [:]

    private static let marker = Data(#""subtype":"away_summary""#.utf8)
    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func recap(in url: URL) -> Recap? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return latest[url] }
        defer { try? handle.close() }

        var start = offsets[url] ?? 0
        let end = (try? handle.seekToEnd()) ?? 0
        if start > end {
            // Shrank: replaced or truncated. Start over.
            start = 0
            latest[url] = nil
        }
        guard (try? handle.seek(toOffset: start)) != nil,
              let data = try? handle.readToEnd(),
              let lastNewline = data.lastIndex(of: 0x0A)
        else { return latest[url] }

        // Only complete lines; a half-written last line is picked up next time.
        for line in data[data.startIndex..<lastNewline].split(separator: 0x0A)
        where line.range(of: Self.marker) != nil {
            guard let record = try? JSONDecoder().decode(Record.self, from: line),
                  let at = Self.timestampFormatter.date(from: record.timestamp)
            else { continue }
            latest[url] = Recap(text: record.content, at: at)
        }
        offsets[url] = start + UInt64(data.distance(from: data.startIndex, to: lastNewline) + 1)
        return latest[url]
    }

    private struct Record: Decodable {
        let content: String
        let timestamp: String
    }
}
