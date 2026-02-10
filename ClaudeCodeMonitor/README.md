# Claude Code Usage Monitor

A native macOS menu bar application for monitoring Claude Code API usage in real-time.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-6.2-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- 📊 **Real-time Usage Tracking**: Monitor API calls, token consumption, and costs
- 💰 **Cost Estimation**: Calculate daily, weekly, and monthly costs with model-specific pricing
- 📈 **Session Analytics**: Track productivity metrics (commits, PRs, lines of code)
- 🛠️ **Tool Statistics**: Monitor tool acceptance rates (Edit, Write, etc.)
- 🔒 **Secure Storage**: API keys stored safely in macOS Keychain
- 🔄 **Auto-refresh**: Background polling every 60 seconds (configurable)
- 🌙 **Dark Mode**: Full support for macOS light/dark themes

## Requirements

- **macOS 14.0 (Sonoma) or later**
- **Xcode 15.0+** (for building)
- **Swift 6.2+**
- **Anthropic Admin API Key** (organization admin role required)

## Installation

### Option 1: Build from Source

```bash
# Clone or navigate to the project directory
cd ClaudeCodeMonitor

# Build the project
swift build -c release

# The binary will be at:
# .build/release/ClaudeCodeMonitor
```

### Option 2: Build with Xcode

```bash
# Generate Xcode project
swift package generate-xcodeproj

# Open in Xcode
open ClaudeCodeMonitor.xcodeproj
```

Then build and run from Xcode (⌘R).

## Getting Your Admin API Key

1. Visit [console.anthropic.com](https://console.anthropic.com)
2. Navigate to **Settings** → **Organization** → **Admin Keys**
3. Click **Create Admin Key** (requires organization admin role)
4. Copy the key (starts with `sk-ant-admin-`)

⚠️ **Important**: Admin API keys are different from regular API keys and provide access to usage reporting across your entire organization.

## Usage

### First Launch

1. Launch the application
2. A bolt icon (⚡) appears in your menu bar
3. Click the icon → **Settings**
4. Enter your Admin API key
5. Click **Test Connection** to verify
6. Click **Save**

The app will immediately start monitoring your usage and refresh every 60 seconds.

### Menu Bar Interface

Click the menu bar icon to view:

```
┌────────────────────────────────┐
│ ⚡ Claude Code Usage Monitor   │
├────────────────────────────────┤
│ 🟢 Active • Updated 2m ago     │
├────────────────────────────────┤
│ TODAY'S USAGE                  │
│ Tokens: 2.4M in • 856K out     │
│ Cache hit rate: 67%            │
│ Cost: $12.45                   │
├────────────────────────────────┤
│ SESSIONS                       │
│ 14 sessions • 23 commits       │
│ 3,421 lines added              │
├────────────────────────────────┤
│ 🔄 Refresh Now                 │
│ ⚙️  Settings                   │
│ ❌ Quit                        │
└────────────────────────────────┘
```

### Icon States

- **⚡ Blue (Active)**: Recent API activity detected
- **⚡ Gray (Idle)**: No recent activity (>2 minutes)
- **⚠️ Orange (Warning)**: Approaching rate limits
- **❌ Red (Error)**: API error or connection issue
- **🔄 Gray (Loading)**: Refreshing data

## Configuration

### Settings Window

Access via menu → **Settings**:

- **API Key**: Your Admin API key (securely stored in Keychain)
- **Refresh Interval**: 30s, 1m, 2m, or 5m (default: 60s)
- **Show Notifications**: Enable/disable error notifications
- **Time Granularity**: 1-minute, 1-hour, or 1-day buckets

### Cost Calculation

The app uses official Anthropic pricing (as of February 2026):

| Model | Input (per MTok) | Output (per MTok) | Cache Write | Cache Read |
|-------|------------------|-------------------|-------------|------------|
| Claude Opus 4.6 | $15.00 | $75.00 | $18.75 | $1.50 |
| Claude Sonnet 4.5 | $3.00 | $15.00 | $3.75 | $0.30 |
| Claude Haiku 4.5 | $0.80 | $4.00 | $1.00 | $0.08 |

Costs are estimates based on token usage. Actual billing may vary.

## Architecture

The application follows MVVM architecture with clean separation of concerns:

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│  (SwiftUI Views + MenuBarExtra)     │
└──────────────┬──────────────────────┘
               │
┌──────────────┴──────────────────────┐
│         ViewModel Layer              │
│     (@Observable ViewModels)        │
└──────────────┬──────────────────────┘
               │
┌──────────────┴──────────────────────┐
│       Business Logic Layer           │
│  (Services + Orchestration)         │
└──────────────┬──────────────────────┘
               │
┌──────────────┴──────────────────────┐
│       Data/Network Layer             │
│  (API Client + Storage)             │
└─────────────────────────────────────┘
```

### Key Components

- **AnthropicAPIClient**: Base HTTP client with auth, retry logic, error handling
- **UsageAPIService**: Interfaces with `/v1/organizations/usage_report/messages`
- **AnalyticsAPIService**: Interfaces with `/v1/organizations/claude_code_analytics`
- **CostCalculationService**: Pricing tables and cost computation
- **UsageMonitorService**: Orchestrates data fetching and state management
- **RefreshScheduler**: Timer-based background polling
- **KeychainService**: Secure API key storage
- **CacheService**: Local JSON cache for historical data

## API Endpoints Used

### Usage API
```
GET /v1/organizations/usage_report/messages
```
- Token usage by model
- Time-bucketed data (1m, 1h, 1d)
- Grouping by model, workspace, API key

### Analytics API
```
GET /v1/organizations/usage_report/claude_code
```
- Session counts
- Lines of code (added/removed)
- Commits and pull requests
- Tool acceptance rates

Both require Admin API key authentication.

## Data Privacy

- ✅ **All data stored locally** (Application Support directory)
- ✅ **API keys in macOS Keychain** (encrypted)
- ✅ **No telemetry or third-party tracking**
- ✅ **No data transmitted except to Anthropic API**
- ✅ **Cache files in user-accessible location**

## Troubleshooting

### "No API key configured"
- Open Settings and enter your Admin API key
- Verify it starts with `sk-ant-admin-`

### "Unauthorized" error
- Check that your API key is valid
- Verify you have organization admin role
- Try regenerating the key in Claude Console

### "Rate limit exceeded"
- Increase refresh interval in Settings
- Default is 60s (Anthropic recommends ≥60s)

### App not appearing in menu bar
- Check System Settings → Privacy → Accessibility
- Try logging out and back in

### "Connection failed"
- Check internet connection
- Verify firewall settings allow outbound HTTPS
- Check if api.anthropic.com is accessible

## Development

### Project Structure

```
ClaudeCodeMonitor/
├── App/                    # Application entry point
├── Models/
│   ├── Domain/            # Business models
│   └── API/               # Codable API models
├── Services/
│   ├── Network/           # API clients
│   ├── Business/          # Orchestration services
│   └── Storage/           # Keychain, UserDefaults, Cache
├── ViewModels/            # @Observable ViewModels
├── Views/
│   ├── MenuBar/           # Main menu content
│   ├── Components/        # Reusable UI components
│   └── Settings/          # Settings window
└── Utilities/             # Helper extensions
```

### Building for Release

```bash
# Build release binary
swift build -c release

# Binary location
.build/release/ClaudeCodeMonitor

# Run
.build/release/ClaudeCodeMonitor
```

### Testing

```bash
# Run tests (when implemented)
swift test

# Build for testing
swift build --build-tests
```

## Roadmap

### v1.1 (Planned)
- [ ] Export reports to CSV
- [ ] Custom cost alert thresholds
- [ ] Multiple workspace support
- [ ] Historical trend charts

### v2.0 (Future)
- [ ] macOS widget integration
- [ ] Slack/Discord webhooks
- [ ] Budget management
- [ ] Team leaderboards
- [ ] ML-based usage forecasting

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Open a pull request

## License

MIT License - see LICENSE file for details

## Support

- **Issues**: Report bugs or request features via GitHub Issues
- **Documentation**: See implementation plan at `~/.claude/plans/`
- **API Docs**: https://docs.anthropic.com/en/api/admin-api

## Credits

Built with:
- Swift & SwiftUI
- Anthropic Admin API
- macOS Keychain Services

---

**Note**: This application requires an Anthropic Admin API key with organization admin permissions. Usage data may have a ~5 minute delay due to API data freshness.
