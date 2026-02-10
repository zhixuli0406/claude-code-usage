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
    private let dateFormatter: ISO8601DateFormatter

    init() {
        self.claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    /// Read all usage data for a given date range
    func fetchUsage(from startDate: Date, to endDate: Date) -> LocalUsageResult {
        let entries = readAllEntries(from: startDate, to: endDate)
        return aggregate(entries: entries)
    }

    /// Read today's usage
    func fetchTodayUsage() -> LocalUsageResult {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return fetchUsage(from: startOfDay, to: Date())
    }

    // MARK: - Private

    private func readAllEntries(from startDate: Date, to endDate: Date) -> [LocalUsageEntry] {
        let fileManager = FileManager.default
        var allEntries: [LocalUsageEntry] = []

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
                allEntries.append(contentsOf: entries)
            }

            // Read subagent JSONL files
            let subagentsDir = projectDir.appendingPathComponent("subagents")
            if fileManager.fileExists(atPath: subagentsDir.path) {
                let subagentFiles = findJSONLFiles(in: subagentsDir)
                for file in subagentFiles {
                    let entries = parseJSONLFile(at: file, from: startDate, to: endDate)
                    allEntries.append(contentsOf: entries)
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
                  type == "assistant",
                  let timestampStr = json["timestamp"] as? String,
                  let timestamp = dateFormatter.date(from: timestampStr),
                  timestamp >= startDate,
                  timestamp <= endDate,
                  let message = json["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else {
                continue
            }

            let model = (message["model"] as? String) ?? "unknown"
            let inputTokens = usage["input_tokens"] as? Int ?? 0
            let outputTokens = usage["output_tokens"] as? Int ?? 0
            let cacheCreation = usage["cache_creation_input_tokens"] as? Int ?? 0
            let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0

            entries.append(LocalUsageEntry(
                timestamp: timestamp,
                sessionId: sessionId,
                model: normalizeModelName(model),
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationInputTokens: cacheCreation,
                cacheReadInputTokens: cacheRead
            ))
        }

        return entries
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
