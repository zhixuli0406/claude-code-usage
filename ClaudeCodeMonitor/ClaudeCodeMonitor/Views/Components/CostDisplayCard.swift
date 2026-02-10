import SwiftUI

/// Card displaying cost estimates with animated ring gauge
@available(macOS 14.0, *)
struct CostDisplayCard: View {
    let cost: Decimal

    @State private var animateRing = false

    /// Daily budget for ring gauge (configurable, default $10)
    private let dailyBudget: Decimal = 10.0

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
            // Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("費用估算")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("今日")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Cost with ring gauge
            HStack(spacing: 12) {
                // Animated ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(ringColor.opacity(0.15), lineWidth: 5)
                        .frame(width: 44, height: 44)

                    // Animated ring
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

                    // Cost text inside ring
                    Text("$\(formatCostShort(cost))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Weekly estimate
                    CostEstimateRow(
                        label: "本週預估",
                        amount: cost * 7,
                        color: .blue
                    )

                    // Monthly estimate
                    CostEstimateRow(
                        label: "月度預估",
                        amount: cost * 30,
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
