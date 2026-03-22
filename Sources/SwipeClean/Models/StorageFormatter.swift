import Foundation

enum StorageFormatter {
    /// Converts bytes to a human-readable string (e.g. "4.5 GB").
    static func humanReadable(bytes: Int64) -> String {
        guard bytes > 0 else { return "0 bytes" }

        let units: [(String, Int64)] = [
            ("GB", 1_073_741_824),
            ("MB", 1_048_576),
            ("KB", 1_024)
        ]

        for (suffix, threshold) in units {
            if bytes >= threshold {
                let value = Double(bytes) / Double(threshold)
                return String(format: "%.1f \(suffix)", value)
            }
        }

        return "\(bytes) bytes"
    }
}
