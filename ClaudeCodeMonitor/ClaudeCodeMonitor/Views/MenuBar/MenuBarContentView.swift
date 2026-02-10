import SwiftUI

/// Main menu bar content view
@available(macOS 14.0, *)
struct MenuBarContentView: View {
    @Bindable var viewModel: MenuBarViewModel
    @State private var contentAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HeaderView(viewModel: viewModel)
            Divider()

            // Status
            StatusView(
                lastRefresh: viewModel.lastRefreshDate,
                isActive: viewModel.iconState == .active
            )
            Divider()

            if viewModel.isLoading {
                LoadingView()
            } else if let error = viewModel.lastError {
                ErrorView(error: error)
            } else if let usage = viewModel.currentUsage {
                // Usage metrics with fade-in
                UsageSection(usage: usage, monthlySpendingLimit: viewModel.monthlySpendingLimit, plan: viewModel.subscriptionPlan, planUsageLimits: viewModel.planUsageLimits)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 8)
                Divider()

                // Sessions
                if !viewModel.sessionHistory.isEmpty {
                    SessionSection(sessions: viewModel.sessionHistory)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 8)
                    Divider()
                }
            } else {
                EmptyStateView()
            }

            // Actions
            ActionsView(viewModel: viewModel)
        }
        .frame(width: 320)
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                contentAppeared = true
            }
        }
        .onDisappear {
            contentAppeared = false
        }
    }
}

/// Header view
@available(macOS 14.0, *)
struct HeaderView: View {
    let viewModel: MenuBarViewModel

    var body: some View {
        HStack {
            Image(systemName: viewModel.iconState.systemImage)
                .foregroundColor(viewModel.iconState.color)
                .symbolEffect(.pulse, isActive: viewModel.isLoading)
            Text("Claude Code 用量")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Status indicator with pulse animation
@available(macOS 14.0, *)
struct StatusView: View {
    let lastRefresh: Date?
    let isActive: Bool

    @State private var isPulsing = false

    private var timeAgoText: String {
        guard let lastRefresh = lastRefresh else { return "尚未更新" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh-TW")
        let timeAgo = formatter.localizedString(for: lastRefresh, relativeTo: Date())
        return "\(isActive ? "運作中" : "閒置") • 更新於 \(timeAgo)"
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .scaleEffect(isPulsing ? 1.4 : 1.0)
                        .opacity(isPulsing ? 0 : 0.6)
                }
                Circle()
                    .fill(isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 14, height: 14)

            Text(timeAgoText)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
    }
}

/// Usage metrics section
@available(macOS 14.0, *)
struct UsageSection: View {
    let usage: UsageMetrics
    let monthlySpendingLimit: Decimal
    let plan: SubscriptionPlan
    let planUsageLimits: PlanUsageLimits?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Plan usage limits (session + weekly + extra)
            if let limits = planUsageLimits {
                Text("方案用量限額")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                PlanUsageLimitsCard(limits: limits, plan: plan)
            }

            Text("今日用量（UTC）")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            TokenUsageCard(breakdown: usage.tokenBreakdown)
            CostDisplayCard(cost: usage.estimatedCost, plan: plan)

            // Model breakdown
            if usage.modelBreakdown.count > 1 {
                ModelBreakdownView(breakdown: usage.modelBreakdown)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Model breakdown mini bars
@available(macOS 14.0, *)
struct ModelBreakdownView: View {
    let breakdown: [String: TokenBreakdown]

    @State private var animateProgress = false

    private var totalTokens: Int {
        breakdown.values.reduce(0) { $0 + $1.total }
    }

    private func modelDisplayName(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "")
            .capitalized
    }

    private func modelColor(_ model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("haiku") { return .cyan }
        return .blue // sonnet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("依模型")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            // Stacked bar
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(
                        breakdown.sorted(by: { $0.value.total > $1.value.total }),
                        id: \.key
                    ) { model, tokens in
                        let fraction = totalTokens > 0
                            ? Double(tokens.total) / Double(totalTokens)
                            : 0

                        RoundedRectangle(cornerRadius: 2)
                            .fill(modelColor(model))
                            .frame(
                                width: animateProgress
                                    ? max(geometry.size.width * fraction, fraction > 0 ? 2 : 0)
                                    : 0
                            )
                    }
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
            )

            // Legend
            HStack(spacing: 8) {
                ForEach(
                    breakdown.sorted(by: { $0.value.total > $1.value.total }),
                    id: \.key
                ) { model, tokens in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(modelColor(model))
                            .frame(width: 6, height: 6)
                        Text(modelDisplayName(model))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                animateProgress = true
            }
        }
    }
}

/// Sessions section
@available(macOS 14.0, *)
struct SessionSection: View {
    let sessions: [SessionData]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("工作階段")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if let todaySession = sessions.first {
                HStack {
                    Image(systemName: "terminal.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("今日 \(todaySession.sessionCount) 個工作階段")
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Actions section
@available(macOS 14.0, *)
struct ActionsView: View {
    let viewModel: MenuBarViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 4) {
            Button(action: {
                Task {
                    await viewModel.refresh()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("立即重新整理")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Button(action: {
                viewModel.openSettings()
                openWindow(id: "settings")
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("設定")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            Button(action: {
                viewModel.quit()
            }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("結束")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

/// Loading view
@available(macOS 14.0, *)
struct LoadingView: View {
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.7)
            Text("載入中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

/// Error view
@available(macOS 14.0, *)
struct ErrorView: View {
    let error: AppError

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("錯誤")
                    .font(.headline)
            }

            Text(error.errorDescription ?? "Unknown error")
                .font(.caption)
                .foregroundColor(.secondary)

            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

/// Empty state view
@available(macOS 14.0, *)
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("尚無用量資料")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("開始使用 Claude Code 即可在此查看用量")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
