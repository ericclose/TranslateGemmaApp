import Foundation

public enum TimeFormatter {
    public static func formatETA(_ time: TimeInterval?) -> String {
        guard let time = time, time >= 0, !time.isInfinite, !time.isNaN else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
