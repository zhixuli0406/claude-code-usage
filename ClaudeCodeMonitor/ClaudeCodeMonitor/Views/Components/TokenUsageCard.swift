import SwiftUI

/// Card displaying token usage metrics with animated progress bars
@available(macOS 14.0, *)
struct TokenUsageCard: View {
    let breakdown: TokenBreakdown

    @State private var animateProgress = false

    private var totalInput: Int {
        breakdown.uncachedInput + breakdown.cachedInput + breakdown.cacheCreation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("Token 用量")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(formatTokens(breakdown.total))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("總計")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Input tokens bar
            TokenProgressRow(
                label: "輸入",
                value: breakdown.uncachedInput,
                total: breakdown.total,
                color: .blue,
                animate: animateProgress
            )

            // Cache read bar
            TokenProgressRow(
                label: "快取讀取",
                value: breakdown.cachedInput,
                total: breakdown.total,
                color: .green,
                animate: animateProgress
            )

            // Cache creation bar
            TokenProgressRow(
                label: "快取寫入",
                value: breakdown.cacheCreation,
                total: breakdown.total,
                color: .orange,
                animate: animateProgress
            )

            // Output bar
            TokenProgressRow(
                label: "輸出",
                value: breakdown.output,
                total: breakdown.total,
                color: .purple,
                animate: animateProgress
            )

            // Cache hit rate
            if breakdown.cachedInput > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("快取命中率")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", breakdown.cacheHitRate * 100))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateProgress = true
            }
        }
    }

    private func formatTokens(_ count: Int) -> String {
        let double = Double(count)
        if double >= 1_000_000 {
            return String(format: "%.1fM", double / 1_000_000)
        } else if double >= 1_000 {
            return String(format: "%.1fK", double / 1_000)
        } else {
            return "\(count)"
        }
    }
}

/// A single token progress row with animated bar
@available(macOS 14.0, *)
struct TokenProgressRow: View {
    let label: String
    let value: Int
    let total: Int
    let color: Color
    let animate: Bool

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTokens(value))
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 6)

                    // Filled bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: animate
                                ? max(geometry.size.width * fraction, fraction > 0 ? 4 : 0)
                                : 0,
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }

    private func formatTokens(_ count: Int) -> String {
        let double = Double(count)
        if double >= 1_000_000 {
            return String(format: "%.1fM", double / 1_000_000)
        } else if double >= 1_000 {
            return String(format: "%.1fK", double / 1_000)
        } else {
            return "\(count)"
        }
    }
}
