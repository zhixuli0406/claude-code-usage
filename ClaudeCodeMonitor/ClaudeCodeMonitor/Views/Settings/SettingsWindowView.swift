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
        .frame(width: 450, height: 350)
        .alert("錯誤", isPresented: $viewModel.showError) {
            Button("確定") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知錯誤")
        }
    }
}
