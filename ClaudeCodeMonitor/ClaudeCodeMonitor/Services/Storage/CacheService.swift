import Foundation

/// Service for caching API responses locally
@available(macOS 14.0, *)
final class CacheService {
    private let fileManager = FileManager.default
    private lazy var cacheDirectory: URL = {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = appSupport.appendingPathComponent("ClaudeCodeMonitor", isDirectory: true)
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir
    }()

    /// Save usage snapshot to cache
    func saveUsageSnapshot<T: Codable>(_ data: T, filename: String) {
        let fileURL = cacheDirectory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let jsonData = try? encoder.encode(data) else { return }
        try? jsonData.write(to: fileURL)
    }

    /// Load cached snapshots
    func loadCachedFiles<T: Codable>(prefix: String, maxAge: TimeInterval) -> [T] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return []
        }

        let cutoffDate = Date().addingTimeInterval(-maxAge)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix(prefix) }
            .compactMap { url -> (Date, T)? in
                guard let data = try? Data(contentsOf: url),
                      let response = try? decoder.decode(T.self, from: data),
                      let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
                      creationDate >= cutoffDate else {
                    return nil
                }
                return (creationDate, response)
            }
            .sorted { $0.0 > $1.0 }
            .map { $0.1 }
    }

    /// Clear old cache files
    func clearOldCache(olderThan days: Int) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        for file in files {
            if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < cutoffDate {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    /// Get cache directory size
    func getCacheSize() -> String {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return "0 KB"
        }

        let totalBytes = files.compactMap { url -> Int64? in
            try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize.map { Int64($0) }
        }.reduce(0, +)

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }

    /// Clear all cache
    func clearAllCache() throws {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files {
            try fileManager.removeItem(at: file)
        }
    }
}
