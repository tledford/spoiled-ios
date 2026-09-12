import Foundation

// Shared tolerant API date parsing used across networking layer.
// Accepts multiple formats: ISO8601 (with/without fractional seconds), yyyy-MM-dd, and unix epoch seconds.
func parseAPIDate(_ raw: String?) -> Date? {
    guard let raw = raw, !raw.isEmpty else { return nil }
    // Try ISO8601 (without fractional seconds first)
    let iso = ISO8601DateFormatter()
    if let d = iso.date(from: raw) { return d }
    iso.formatOptions.insert(.withFractionalSeconds)
    if let d = iso.date(from: raw) { return d }
    // yyyy-MM-dd
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)
    df.dateFormat = "yyyy-MM-dd"
    if let d = df.date(from: raw) { return d }
    // Unix seconds
    if let seconds = TimeInterval(raw) { return Date(timeIntervalSince1970: seconds) }
    return nil
}
