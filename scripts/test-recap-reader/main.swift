// Self-check for RecapReader. Run:
// swiftc -o /tmp/recap-check Sources/HUD/RecapReader.swift scripts/test-recap-reader/main.swift && /tmp/recap-check
import Foundation

let url = FileManager.default.temporaryDirectory.appendingPathComponent("recap-\(UUID()).jsonl")
func append(_ s: String) {
    let h = try! FileHandle(forWritingTo: url)
    h.seekToEndOfFile(); h.write(Data(s.utf8)); try! h.close()
}
func recap(_ text: String, _ ts: String) -> String {
    #"{"type":"system","subtype":"away_summary","content":"\#(text)","timestamp":"\#(ts)"}"# + "\n"
}

FileManager.default.createFile(atPath: url.path, contents: Data())
let reader = RecapReader()
assert(reader.recap(in: url) == nil)

append(#"{"type":"user","message":{"content":"hi"}}"# + "\n" + recap("first", "2026-10-05T15:24:19.560Z"))
assert(reader.recap(in: url)?.text == "first")

// A half-written line is not read until its newline lands.
let second = recap("second", "2026-10-05T16:00:00.000Z")
append(String(second.prefix(30)))
assert(reader.recap(in: url)?.text == "first")
append(String(second.dropFirst(30)))
assert(reader.recap(in: url)?.text == "second")

// Unrelated lines keep the latest recap.
append(#"{"type":"assistant","message":{"content":"ok"}}"# + "\n")
assert(reader.recap(in: url)?.text == "second")

// Replaced with a shorter file: rescan from the start.
try! Data(recap("fresh", "2026-10-06T00:00:00.000Z").utf8).write(to: url)
assert(reader.recap(in: url)?.text == "fresh")

print("ok")
