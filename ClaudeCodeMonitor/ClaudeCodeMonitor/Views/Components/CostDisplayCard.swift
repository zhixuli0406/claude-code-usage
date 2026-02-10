import SwiftUI

/// Card displaying cost estimates with plan-aware ring gauge
/// Ring shows today's cost vs plan's estimated daily API budget
@available(macOS 14.0, *)
struct CostDisplayCard: View {
    let cost: Decimal
    let plan: SubscriptionPlan

    @State private var animateRing = false

    private var dailyBudget: Decimal {
        plan.estimatedDailyBudget
    }

    /// Extra cost beyond the plan's included daily budget
    private var dailyExtra: Decimal {
        max(0, cost - dailyBudget)
    }

    private var budgetFraction: Double {
        guard dailyBudget > 0 else { return 0 }
        return min(Double(truncating: (cost / dailyBudget) as NSDecimalNumber), 1.0)
    }

    private var ringColor: Color {
        if budgetFraction < 0.5 { return .green }
        if budgetFraction < 0.8 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with plan badge
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("費用估算")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                // Plan badge
                Text(plan.displayName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(plan.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(plan.color.opacity(0.15))
                    .cornerRadius(4)
            }

            // Cost with ring gauge
            HStack(spacing: 12) {
                // Animated ring (plan-colored)
                ZStack {
                    Circle()
                        .stroke(ringColor.opacity(0.15), lineWidth: 5)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: animateRing ? budgetFraction : 0)
                        .stroke(
                            AngularGradient(
                                colors: [ringColor.opacity(0.7), ringColor],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))

                    Text("$\(formatCostShort(cost))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Daily budget from plan
                    CostEstimateRow(
                        label: "方案日額",
                        amount: dailyBudget,
                        color: plan.color
                    )

                    // Weekly extra cost (only the part exceeding plan)
                    CostEstimateRow(
                        label: "本週預估",
                        amount: dailyExtra * 7,
                        color: .blue
                    )

                    // Monthly extra cost (only the part exceeding plan)
                    CostEstimateRow(
                        label: "月度預估",
                        amount: dailyExtra * 30,
                        color: .purple
                    )
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animateRing = true
            }
        }
    }

    private func formatCostShort(_ amount: Decimal) -> String {
        let nsNumber = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: nsNumber) ?? "0.00"
    }
}

/// Card displaying extra usage budget matching official Claude usage page
@available(macOS 14.0, *)
struct ExtraUsageCard: View {
    let dailyCost: Decimal
    let monthlySpendingLimit: Decimal
    let plan: SubscriptionPlan

    @State private var animateBar = false

    /// Daily extra cost beyond plan's included budget
    private var dailyExtra: Decimal {
        max(0, dailyCost - plan.estimatedDailyBudget)
    }

    /// Projected monthly extra usage cost
    private var monthlyExtraProjected: Decimal {
        dailyExtra * 30
    }

    private var usageFraction: Double {
        guard monthlySpendingLimit > 0 else { return 0 }
        return min(Double(truncating: (monthlyExtraProjected / monthlySpendingLimit) as NSDecimalNumber), 1.0)
    }

    private var barColor: Color {
        if usageFraction < 0.5 { return .blue }
        if usageFraction < 0.8 { return .orange }
        return .red
    }

    private var nextResetDate: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        var components = calendar.dateComponents([.year, .month], from: now)
        components.month! += 1
        components.day = 1
        if let resetDate = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh-TW")
            formatter.timeZone = TimeZone(identifier: "UTC")!
            formatter.dateFormat = "M 月 d 日"
            return formatter.string(from: resetDate)
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with plan context
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(plan.color)
                    .font(.caption)
                Text("額外用量")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("$\(formatCost(plan.monthlyPrice))/月")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            // Monthly extra projected vs limit
            HStack {
                Text("額外預估")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(formatCost(monthlyExtraProjected))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(monthlyExtraProjected > monthlySpendingLimit ? .red : .primary)
                    .monospacedDigit()
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(
                            width: animateBar
                                ? geometry.size.width * usageFraction
                                : 0,
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            // Budget info
            HStack {
                Image(systemName: "dollarsign.circle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("$\(formatCost(monthlySpendingLimit))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()

                Spacer()

                Text("月額上限 · \(nextResetDate)重設 (UTC)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                animateBar = true
            }
        }
    }

    private func formatCost(_ amount: Decimal) -> String {
        let nsNumber = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: nsNumber) ?? "0.00"
    }
}

/// A row showing a cost estimate with a small inline bar
@available(macOS 14.0, *)
struct CostEstimateRow: View {
    let label: String
    let amount: Decimal
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text("$\(formatCost(amount))")
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }

    private func formatCost(_ amount: Decimal) -> String {
        let nsNumber = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: nsNumber) ?? "0.00"
    }
}
