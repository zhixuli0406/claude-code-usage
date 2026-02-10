##快速开始指南

### 1 分钟启动

```bash
# 1. 构建项目
swift build -c release

# 2. 运行应用
.build/release/ClaudeCodeMonitor
```

或者使用快速启动脚本：

```bash
./run.sh
```

### 首次设置

1. **启动应用** → 菜单栏出现 ⚡ 图标
2. **点击图标** → 选择 "Settings"
3. **输入 API Key**：
   - 访问 [console.anthropic.com](https://console.anthropic.com)
   - Settings → Organization → Admin Keys
   - 创建新密钥（需要组织管理员权限）
   - 复制密钥（`sk-ant-admin-...`）
4. **测试连接** → 点击 "Test Connection"
5. **保存** → 应用开始监控

### 获取 Admin API Key

⚠️ **重要**：需要组织管理员权限

1. 登录 [console.anthropic.com](https://console.anthropic.com)
2. 点击 **Settings** (⚙️)
3. 选择 **Organization** 标签
4. 滚动到 **Admin Keys** 部分
5. 点击 **Create Admin Key**
6. 复制密钥并保存（只显示一次）

### 菜单栏功能

点击 ⚡ 图标查看：

- **实时用量**：Token 使用量、缓存命中率
- **成本估算**：今日、本周、预计月度成本
- **会话统计**：提交数、代码行数
- **工具统计**：Edit、Write 等工具的接受率

### 配置选项

**刷新间隔**：
- 30 秒（不推荐）
- **60 秒**（推荐，默认）
- 2 分钟
- 5 分钟

**时间粒度**：
- 1 分钟（实时）
- 1 小时（日常）
- 1 天（报告）

### 常见问题

**Q: 看不到数据？**
A: 等待 5 分钟。Anthropic API 有 ~5 分钟延迟。

**Q: "Unauthorized" 错误？**
A: 检查：
- API key 格式（`sk-ant-admin-`）
- 是否有组织管理员权限
- Key 是否仍然有效

**Q: "Rate limit exceeded"？**
A: 将刷新间隔增加到 2 分钟或更长。

**Q: 成本不准确？**
A:
- 这是估算值，基于 Token 使用和官方定价
- 实际账单可能略有不同
- 查看 Claude Console 获取精确数据

### 数据位置

- **API Key**：macOS Keychain（加密）
- **配置**：`~/Library/Preferences/`
- **缓存**：`~/Library/Application Support/ClaudeCodeMonitor/`

### 卸载

```bash
# 删除 API Key
# 在应用内：Settings → Delete API Key

# 删除缓存
rm -rf ~/Library/Application\ Support/ClaudeCodeMonitor/

# 删除应用
rm .build/release/ClaudeCodeMonitor
```

### 技术要求

- macOS 14.0 (Sonoma) 或更高版本
- Admin API Key（组织管理员权限）
- 互联网连接

### 下一步

- 查看 [README.md](README.md) 了解完整功能
- 查看实现计划：`~/.claude/plans/dynamic-waddling-pnueli.md`
- 报告问题或请求功能

---

**提示**：应用会在后台每 60 秒自动刷新数据。保持应用运行以持续监控。
