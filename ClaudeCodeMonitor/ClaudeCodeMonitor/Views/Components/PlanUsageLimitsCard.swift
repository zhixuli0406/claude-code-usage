import SwiftUI

/// Data for a single limit progress bar
struct LimitBarData {
    let label: String
    let resetText: String
    let usagePercent: Int
    let fraction: Double
    let color: Color
}

/// Card displaying plan usage limits matching the official Claude usage page
@available(macOS 14.0, *)
struct PlanUsageLimitsCard: View {
    let limits: PlanUsageLimits
    let plan: SubscriptionPlan

    @State private var animateBars = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section 1: Session
            LimitSection(
                title: "工作階段",
                icon: "clock.arrow.circlepath",
                iconColor: .blue,
                items: [
                    LimitBarData(
                        label: "目前工作階段",
                        resetText: limits.session.resetDescription,
                        usagePercent: limits.session.usagePercent,
                        fraction: limits.session.usageFraction,
                        color: fractionColor(limits.session.usageFraction)
                    )
                ],
                animate: animateBars
            )

            Divider()

            // Section 2: Weekly limits
            LimitSection(
                title: "每週限額",
                icon: "calendar",
                iconColor: .purple,
                items: [
                    LimitBarData(
                        label: "所有模型",
                        resetText: limits.weeklyAllModels.resetDescription,
                        usagePercent: limits.weeklyAllModels.usagePercent,
                        fraction: limits.weeklyAllModels.usageFraction,
                        color: fractionColor(limits.weeklyAllModels.usageFraction)
                    ),
                    LimitBarData(
                        label: "僅 Sonnet",
                        resetText: limits.weeklySonnetOnly.resetDescription,
                        usagePercent: limits.weeklySonnetOnly.usagePercent,
                        fraction: limits.weeklySonnetOnly.usageFraction,
                        color: fractionColor(limits.weeklySonnetOnly.usageFraction)
                    )
                ],
                animate: animateBars
            )

            Divider()

            // Section 3: Extra usage
            ExtraUsageLimitBar(info: limits.extraUsage, animate: animateBars)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                animateBars = true
            }
        }
    }

    private func fractionColor(_ fraction: Double) -> Color {
        if fraction < 0.5 { return .blue }
        if fraction < 0.8 { return .orange }
        return .red
    }
}

/// A section with a title and one or more limit bars
@available(macOS 14.0, *)
struct LimitSection: View {
    let title: String
    let icon: String
    let iconColor: Color
    let items: [LimitBarData]
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                LimitBarRow(data: item, animate: animate)
            }
        }
    }
}

/// A single limit bar row with label, reset text, progress bar, and percentage
@available(macOS 14.0, *)
struct LimitBarRow: View {
    let data: LimitBarData
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(data.label)
                    .font(.caption)
                    .foregroundColor(.primary)
                Spacer()
                Text(data.resetText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(data.color)
                            .frame(
                                width: animate
                                    ? geometry.size.width * min(data.fraction, 1.0)
                                    : 0,
                                height: 6
                            )
                    }
                }
                .frame(height: 6)

                Text("\(data.usagePercent)%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(data.color)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}

/// Extra usage section with spent/limit info
@available(macOS 14.0, *)
struct ExtraUsageLimitBar: View {
    let info: ExtraUsageLimitInfo
    let animate: Bool

    private var barColor: Color {
        if info.usageFraction < 0.5 { return .blue }
        if info.usageFraction < 0.8 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("額外用量")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(formatResetDate(info.resetDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor)
                            .frame(
                                width: animate
                                    ? geometry.size.width * min(CGFloat(info.usageFraction), 1.0)
                                    : 0,
                                height: 6
                            )
                    }
                }
                .frame(height: 6)

                Text("\(info.usagePercent)%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }

            HStack {
                Text("$\(formatDecimal(info.spent)) 已花費")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(formatDecimal(info.monthlyLimit)) 月額上限")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatResetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-TW")
        formatter.timeZone = TimeZone(identifier: "UTC")!
        formatter.dateFormat = "M 月 d 日重設"
        return formatter.string(from: date)
    }

    private func formatDecimal(_ value: Decimal) -> String {
        let nsNumber = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: nsNumber) ?? "0.00"
    }
}
