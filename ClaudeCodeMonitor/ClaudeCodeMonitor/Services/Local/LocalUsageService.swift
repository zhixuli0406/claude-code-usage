import Foundation

/// Parsed usage entry from a local JSONL file
struct LocalUsageEntry {
    let timestamp: Date
    let sessionId: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int
    let costUSD: Decimal?       // Pre-computed cost from JSONL (costUSD / cost_usd / cost)
    let deduplicationKey: String // message_id:request_id for deduplication
}

/// Result of aggregating local usage data
struct LocalUsageResult {
    let entries: [LocalUsageEntry]
    let totalBreakdown: TokenBreakdown
    let modelBreakdown: [String: TokenBreakdown]
    let sessionCount: Int
    let projectCount: Int
}

/// Service for reading Claude Code usage from local JSONL files
@available(macOS 14.0, *)
final class LocalUsageService {

    private let claudeDir: URL
    private let dateFormatters: [ISO8601DateFormatter]

    init() {
        self.claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        // Support multiple ISO 8601 variants
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]

        self.dateFormatters = [withFractional, standard]
    }

    /// Read all usage data for a given date range
    func fetchUsage(from startDate: Date, to endDate: Date) -> LocalUsageResult {
        let entries = readAllEntries(from: startDate, to: endDate)
        return aggregate(entries: entries)
    }

    /// Read today's usage (UTC day boundary, matching Anthropic's backend)
    func fetchTodayUsage() -> LocalUsageResult {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let startOfDay = calendar.startOfDay(for: Date())
        return fetchUsage(from: startOfDay, to: Date())
    }

    // MARK: - Private

    private func readAllEntries(from startDate: Date, to endDate: Date) -> [LocalUsageEntry] {
        let fileManager = FileManager.default
        var allEntries: [LocalUsageEntry] = []
        var seenKeys: Set<String> = []

        guard let projectDirs = try? fileManager.contentsOfDirectory(
            at: claudeDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: projectDir.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            // Read main session JSONL files
            let jsonlFiles = findJSONLFiles(in: projectDir)
            for file in jsonlFiles {
                let entries = parseJSONLFile(at: file, from: startDate, to: endDate)
                for entry in entries {
                    if seenKeys.insert(entry.deduplicationKey).inserted {
                        allEntries.append(entry)
                    }
                }
            }

            // Read subagent JSONL files
            let subagentsDir = projectDir.appendingPathComponent("subagents")
            if fileManager.fileExists(atPath: subagentsDir.path) {
                let subagentFiles = findJSONLFiles(in: subagentsDir)
                for file in subagentFiles {
                    let entries = parseJSONLFile(at: file, from: startDate, to: endDate)
                    for entry in entries {
                        if seenKeys.insert(entry.deduplicationKey).inserted {
                            allEntries.append(entry)
                        }
                    }
                }
            }
        }

        return allEntries
    }

    private func findJSONLFiles(in directory: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents.filter { $0.pathExtension == "jsonl" }
    }

    private func parseJSONLFile(
        at fileURL: URL,
        from startDate: Date,
        to endDate: Date
    ) -> [LocalUsageEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        // Derive sessionId from filename (UUID part of filename)
        let sessionId = fileURL.deletingPathExtension().lastPathComponent

        var entries: [LocalUsageEntry] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String,
                  type == "assistant" else {
                continue
            }

            // Parse timestamp (multiple formats)
            guard let timestamp = parseTimestamp(from: json),
                  timestamp >= startDate,
                  timestamp <= endDate else {
                continue
            }

            // Extract token data from multiple possible locations
            let message = json["message"] as? [String: Any]
            guard let usage = extractUsage(from: json, message: message) else {
                continue
            }

            let model = extractModel(from: json, message: message)
            let inputTokens = extractInt(from: usage, keys: ["input_tokens", "inputTokens", "prompt_tokens"])
            let outputTokens = extractInt(from: usage, keys: ["output_tokens", "outputTokens", "completion_tokens"])
            let cacheCreation = extractInt(from: usage, keys: ["cache_creation_input_tokens", "cache_creation_tokens", "cacheCreationInputTokens"])
            let cacheRead = extractInt(from: usage, keys: ["cache_read_input_tokens", "cache_read_tokens", "cacheReadInputTokens"])

            // Build deduplication key from message_id + request_id
            let deduplicationKey = buildDeduplicationKey(from: json, message: message)

            // Extract pre-computed cost if available
            let costUSD = extractCostUSD(from: json)

            entries.append(LocalUsageEntry(
                timestamp: timestamp,
                sessionId: sessionId,
                model: normalizeModelName(model),
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationInputTokens: cacheCreation,
                cacheReadInputTokens: cacheRead,
                costUSD: costUSD,
                deduplicationKey: deduplicationKey
            ))
        }

        return entries
    }

    // MARK: - Token Extraction Helpers

    /// Extract usage dict from multiple possible JSON paths (message.usage > usage > root)
    private func extractUsage(from json: [String: Any], message: [String: Any]?) -> [String: Any]? {
        // Priority: message.usage > usage > root-level token keys
        if let msgUsage = message?["usage"] as? [String: Any] {
            return msgUsage
        }
        if let rootUsage = json["usage"] as? [String: Any] {
            return rootUsage
        }
        // Check if token keys exist at root level
        if json["input_tokens"] != nil || json["inputTokens"] != nil || json["prompt_tokens"] != nil {
            return json
        }
        return nil
    }

    /// Extract model name from multiple possible locations
    private func extractModel(from json: [String: Any], message: [String: Any]?) -> String {
        if let model = json["model"] as? String { return model }
        if let model = message?["model"] as? String { return model }
        return "unknown"
    }

    /// Extract first matching integer value from multiple possible key names
    private func extractInt(from dict: [String: Any], keys: [String]) -> Int {
        for key in keys {
            if let value = dict[key] as? Int { return value }
        }
        return 0
    }

    /// Parse timestamp from multiple formats
    private func parseTimestamp(from json: [String: Any]) -> Date? {
        // Try string timestamp first
        if let timestampStr = json["timestamp"] as? String {
            for formatter in dateFormatters {
                if let date = formatter.date(from: timestampStr) {
                    return date
                }
            }
            // Try parsing "Z" suffix variant manually
            let cleaned = timestampStr.replacingOccurrences(of: "Z", with: "+00:00")
            for formatter in dateFormatters {
                if let date = formatter.date(from: cleaned) {
                    return date
                }
            }
        }
        // Try numeric Unix timestamp (seconds since epoch)
        if let ts = json["timestamp"] as? Double {
            return Date(timeIntervalSince1970: ts)
        }
        if let ts = json["timestamp"] as? Int {
            return Date(timeIntervalSince1970: TimeInterval(ts))
        }
        return nil
    }

    /// Build deduplication key from message_id + request_id
    private func buildDeduplicationKey(from json: [String: Any], message: [String: Any]?) -> String {
        let messageId = (json["message_id"] as? String)
            ?? (message?["id"] as? String)
            ?? UUID().uuidString
        let requestId = (json["request_id"] as? String)
            ?? (json["requestId"] as? String)
            ?? ""
        return "\(messageId):\(requestId)"
    }

    /// Extract pre-computed cost from JSONL entry
    private func extractCostUSD(from json: [String: Any]) -> Decimal? {
        let keys = ["costUSD", "cost_usd", "cost"]
        for key in keys {
            if let value = json[key] as? Double, value > 0 {
                return Decimal(value)
            }
            if let value = json[key] as? NSNumber {
                let decimal = value.decimalValue
                if decimal > 0 { return decimal }
            }
        }
        return nil
    }

    private func aggregate(entries: [LocalUsageEntry]) -> LocalUsageResult {
        var totalUncached = 0
        var totalCached = 0
        var totalCacheCreation = 0
        var totalOutput = 0
        var modelBreakdown: [String: TokenBreakdown] = [:]
        var sessionIds: Set<String> = []
        var projectNames: Set<String> = []

        for entry in entries {
            totalUncached += entry.inputTokens
            totalCached += entry.cacheReadInputTokens
            totalCacheCreation += entry.cacheCreationInputTokens
            totalOutput += entry.outputTokens
            sessionIds.insert(entry.sessionId)

            // Extract project name from sessionId path context
            // (sessionId is the filename, project context comes from directory)
            let existing = modelBreakdown[entry.model] ?? TokenBreakdown(
                uncachedInput: 0, cachedInput: 0, cacheCreation: 0, output: 0
            )
            modelBreakdown[entry.model] = TokenBreakdown(
                uncachedInput: existing.uncachedInput + entry.inputTokens,
                cachedInput: existing.cachedInput + entry.cacheReadInputTokens,
                cacheCreation: existing.cacheCreation + entry.cacheCreationInputTokens,
                output: existing.output + entry.outputTokens
            )
        }

        // Count projects from parent directories
        // Each unique sessionId prefix before the UUID represents a project
        for id in sessionIds {
            projectNames.insert(id)
        }

        let totalBreakdown = TokenBreakdown(
            uncachedInput: totalUncached,
            cachedInput: totalCached,
            cacheCreation: totalCacheCreation,
            output: totalOutput
        )

        return LocalUsageResult(
            entries: entries,
            totalBreakdown: totalBreakdown,
            modelBreakdown: modelBreakdown,
            sessionCount: sessionIds.count,
            projectCount: projectNames.count
        )
    }

    /// Normalize model name by stripping date suffixes
    /// e.g. "claude-sonnet-4-5-20250929" -> "claude-sonnet-4-5"
    private func normalizeModelName(_ model: String) -> String {
        // Match pattern: model-name-YYYYMMDD
        let pattern = #"-\d{8}$"#
        if let range = model.range(of: pattern, options: .regularExpression) {
            return String(model[model.startIndex..<range.lowerBound])
        }
        return model
    }
}
