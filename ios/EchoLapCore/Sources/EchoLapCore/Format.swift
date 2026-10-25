import Foundation

/// Race times as players read them: "1:12.48", "48.20", deltas "+0.42" / "−0.42" (true minus sign).
public enum TimeFormat {
    public static func race(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "–:––.––" }
        let hundredths = Int((seconds * 100).rounded())
        let m = hundredths / 6000
        let s = (hundredths / 100) % 60
        let h = hundredths % 100
        return m > 0 ? String(format: "%d:%02d.%02d", m, s, h) : String(format: "%d.%02d", s, h)
    }

    public static func delta(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "" }
        let value = String(format: "%.2f", abs(seconds))
        return (seconds < 0 ? "\u{2212}" : "+") + value
    }

    /// Spoken form for VoiceOver: "1 minute 12.48 seconds".
    public static func spoken(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "no time" }
        let m = Int(seconds) / 60
        let rest = seconds - Double(m * 60)
        let s = String(format: "%.2f", rest)
        return m > 0 ? "\(m) minute\(m == 1 ? "" : "s") \(s) seconds" : "\(s) seconds"
    }
}
