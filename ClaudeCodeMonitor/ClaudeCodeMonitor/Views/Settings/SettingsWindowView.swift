import SwiftUI

/// Settings window view
@available(macOS 14.0, *)
struct SettingsWindowView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            // Data Source
            Section {
                Text("從 ~/.claude/projects/ 讀取用量資料")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("資料來源")
            }

            // Refresh Settings
            Section {
                Picker("更新頻率", selection: $viewModel.refreshInterval) {
                    Text("30 秒").tag(TimeInterval(30))
                    Text("1 分鐘").tag(TimeInterval(60))
                    Text("2 分鐘").tag(TimeInterval(120))
                    Text("5 分鐘").tag(TimeInterval(300))
                }

                Toggle("顯示通知", isOn: $viewModel.showNotifications)

                Toggle("登入時啟動", isOn: $viewModel.launchAtLogin)
            } header: {
                Text("更新設定")
            }

            // Subscription Plan
            Section {
                Picker("訂閱方案", selection: $viewModel.subscriptionPlan) {
                    ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                        HStack {
                            Text(plan.displayName)
                            if plan.monthlyPrice > 0 {
                                Text("$\(plan.monthlyPrice as NSDecimalNumber)/月")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(plan)
                    }
                }

                HStack {
                    Text("預估日額")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$\(viewModel.subscriptionPlan.estimatedDailyBudget as NSDecimalNumber)/日")
                        .foregroundColor(viewModel.subscriptionPlan.color)
                        .fontWeight(.medium)
                }
                .font(.caption)

                Text("環形圖依據方案估算的每日 API 等值額度顯示使用率")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("訂閱方案")
            }

            // Budget Settings
            Section {
                HStack {
                    Text("月額預算上限")
                    Spacer()
                    TextField(
                        "$",
                        value: $viewModel.monthlySpendingLimit,
                        format: .currency(code: "USD")
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .multilineTextAlignment(.trailing)
                }
                Text("對應 Claude 訂閱的 Extra Usage 月額上限")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("額外用量")
            }

            // Weekly Reset Settings
            Section {
                Picker("每週重設日", selection: $viewModel.weeklyResetDayOfWeek) {
                    Text("星期日").tag(1)
                    Text("星期一").tag(2)
                    Text("星期二").tag(3)
                    Text("星期三").tag(4)
                    Text("星期四").tag(5)
                    Text("星期五").tag(6)
                    Text("星期六").tag(7)
                }

                Picker("每週重設時間", selection: $viewModel.weeklyResetHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }

                Text("對應 Claude 官方用量頁面的每週重設週期")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("每週重設")
            }

            // Budget Calibration
            Section {
                BudgetRow(
                    label: "工作階段 (5h)",
                    placeholder: "$\(viewModel.subscriptionPlan.defaultSessionBudget as NSDecimalNumber)",
                    text: $viewModel.sessionBudgetText
                )
                BudgetRow(
                    label: "每週全模型",
                    placeholder: "$\(viewModel.subscriptionPlan.defaultWeeklyAllModelsBudget as NSDecimalNumber)",
                    text: $viewModel.weeklyAllModelsBudgetText
                )
                BudgetRow(
                    label: "每週 Sonnet",
                    placeholder: "$\(viewModel.subscriptionPlan.defaultWeeklySonnetBudget as NSDecimalNumber)",
                    text: $viewModel.weeklySonnetBudgetText
                )
                Text("留空使用方案預設值；可參考官方用量頁面百分比來微調")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("預算校正")
            }

            // Display Options
            Section {
                Picker("時間粒度", selection: $viewModel.selectedTimeGranularity) {
                    ForEach(TimeGranularity.allCases, id: \.self) { granularity in
                        Text(granularity.displayName).tag(granularity)
                    }
                }
            } header: {
                Text("顯示選項")
            }

            // Actions
            HStack {
                Spacer()

                Button("取消") {
                    NSApplication.shared.keyWindow?.close()
                }

                Button("儲存") {
                    viewModel.saveSettings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApplication.shared.keyWindow?.close()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 780)
        .alert("錯誤", isPresented: $viewModel.showError) {
            Button("確定") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知錯誤")
        }
    }
}

/// A row for budget override input
@available(macOS 14.0, *)
struct BudgetRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
        }
    }
}
