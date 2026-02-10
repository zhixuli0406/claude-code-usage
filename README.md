# Claude Code Monitor

A native macOS menu bar app that monitors your [Claude Code](https://docs.anthropic.com/en/docs/claude-code) usage in real-time by reading local JSONL log files. No API key required.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Plan Usage Limits** — Session, weekly, and Sonnet-only usage percentages matching the official Claude usage page
- **Auto Session Detection** — Automatically detects 5-hour session boundaries from entry gaps (no manual sync needed)
- **Token Breakdown** — Input, output, cache creation, and cache read tokens with hit-rate indicator
- **Cost Estimation** — Per-model cost tracking using official API pricing
- **Model Breakdown** — See usage split across Opus, Sonnet, Haiku, etc.
- **Deduplication** — Prevents double-counting via `message_id:request_id` keys
- **Extra Usage Tracking** — Monthly extra usage vs. your configured spending limit
- **Launch at Login** — Optionally start with macOS
- **Zero Dependencies** — Pure Swift & SwiftUI, no third-party libraries
- **Privacy First** — All data stays local; reads `~/.claude/projects/` directly

## How It Works

Claude Code writes JSONL log files to `~/.claude/projects/` on every API interaction. This app reads those files, extracts token counts and model info, and computes usage metrics locally.

```
~/.claude/projects/**/*.jsonl
        |
   LocalUsageService (parse + deduplicate)
        |
   CostCalculationService (API pricing + usage weight)
        |
   UsageMonitorService (session detection + plan limits)
        |
   MenuBarContentView (SwiftUI)
```

### Usage Weight System

Anthropic's plan usage limits use internal compute-cost rates, which differ from public API pricing. For example, Opus 4.5+ API pricing dropped to $5/$25 per MTok, but plan limits still reflect the higher compute cost ($15/$75). This app applies a **dual pricing model**:

| Purpose | Opus 4.6 | Sonnet 4.5 | Haiku 4.5 |
|---------|----------|------------|-----------|
| **Cost display** (actual $) | $5 / $25 | $3 / $15 | $1 / $5 |
| **Usage % calculation** | $15 / $75 | $3 / $15 | $1 / $5 |

*Input / Output per million tokens. Cache pricing: write = 1.25x input, read = 0.1x input.*

Reference: [Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) for the compute-cost pricing approach.

## Screenshots

```
┌──────────────────────────────────┐
│  ⚡ Claude Code Monitor          │
├──────────────────────────────────┤
│  🟢 Active • Updated 30s ago     │
├──────────────────────────────────┤
│  ⏱ Session         3h 20m reset  │
│  ███░░░░░░░░░░░░░░░░░░░  11%    │
│                                  │
│  📅 Weekly Limits                │
│  All models        Tue 08:00     │
│  ██░░░░░░░░░░░░░░░░░░░░░  7%    │
│  Sonnet only       Tue 08:00     │
│  █░░░░░░░░░░░░░░░░░░░░░░  2%    │
│                                  │
│  💳 Extra Usage    Mar 1 reset   │
│  $0.00 / $20.00            0%    │
├──────────────────────────────────┤
│  Token Usage        1.2M total   │
│  Cost Today              $2.45   │
├──────────────────────────────────┤
│  🔄 Refresh  ⚙️ Settings  ❌ Quit │
└──────────────────────────────────┘
```

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Xcode 15.0+** or Swift 5.9+ toolchain (for building)
- **Claude Code** installed and used (generates `~/.claude/projects/` data)

## Installation

### Build & Install (recommended)

```bash
git clone https://github.com/zhixuli0406/claude-code-usage.git
cd claude-code-usage/ClaudeCodeMonitor

# Build .app bundle and install to /Applications
./install.sh
```

### Build Only

```bash
cd ClaudeCodeMonitor

# Build .app bundle (stays in project directory)
./build-app.sh

# Or build binary directly
swift build -c release
.build/release/ClaudeCodeMonitor
```

### Run from Source

```bash
./run.sh
# or
swift run
```

## Configuration

Click the menu bar icon → **Settings** to configure:

| Setting | Default | Description |
|---------|---------|-------------|
| Subscription Plan | Pro | Free / Pro / Max 5x / Max 20x / Team / Team Premium |
| Refresh Interval | 60s | How often to re-read JSONL files (30s–5min) |
| Weekly Reset | Tue 08:00 | Day and hour for weekly limit reset |
| Monthly Spending Limit | $20 | Extra usage cap per month |
| Launch at Login | Off | Auto-start with macOS |

### Budget Overrides

Each usage limit has a default budget calibrated against the official Claude usage page. You can override them in Settings:

- **Session Budget** — 5-hour session limit (default: $8 compute-cost for Pro)
- **Weekly All Models** — Weekly all-model limit (default: $95 for Pro)
- **Weekly Sonnet** — Weekly Sonnet-only limit (default: $10 for Pro)

Leave fields empty to use plan defaults. Max plans use 5x/20x multipliers.

### Session Reset

The app auto-detects session boundaries by scanning for **gaps >= 5 hours** between entries. You can also manually set the remaining time via the gear icon next to the session progress bar (useful for syncing with the official usage page).

## Project Structure

```
ClaudeCodeMonitor/
├── App/                          # @main entry point (MenuBarExtra)
├── Models/
│   ├── Domain/                   # UsageMetrics, PlanUsageLimits
│   └── API/                      # TokenBreakdown, API response types
├── Services/
│   ├── Local/                    # JSONL file reader + parser
│   │   └── LocalUsageService     #   Dedup, multi-format timestamps,
│   │                             #   multi-path token extraction
│   ├── Business/
│   │   ├── UsageMonitorService   #   Orchestration, session detection,
│   │   │                         #   plan limit calculation
│   │   ├── CostCalculationService#   Dual pricing (API + usage weight)
│   │   └── RefreshScheduler      #   Timer-based background polling
│   ├── Storage/
│   │   ├── UserDefaultsService   #   Plan config, budgets, preferences
│   │   ├── KeychainService       #   Secure API key storage
│   │   └── LaunchAtLoginService  #   SMAppService integration
│   └── Network/                  #   (Legacy API client, not used for
│       └── ...                   #    local-only mode)
├── ViewModels/
│   ├── MenuBarViewModel          # Main menu bar state
│   └── SettingsViewModel         # Settings form state
└── Views/
    ├── MenuBar/                  # MenuBarContentView
    ├── Components/               # CostDisplayCard, TokenUsageCard,
    │                             # PlanUsageLimitsCard
    └── Settings/                 # SettingsWindowView
```

## Technical Details

### JSONL Parsing

Reads `~/.claude/projects/**/*.jsonl` including `subagents/` directories. Supports:

- **Multiple token paths**: `message.usage` > `usage` > root-level keys
- **Multiple field names**: `input_tokens` / `inputTokens` / `prompt_tokens`, etc.
- **Multiple timestamp formats**: ISO 8601 (with/without fractional seconds), Unix timestamps
- **Pre-computed cost**: Uses `costUSD` / `cost_usd` from JSONL when available
- **Deduplication**: `message_id:request_id` composite key prevents double-counting
- **Model normalization**: Strips date suffixes (e.g., `claude-sonnet-4-5-20250929` → `claude-sonnet-4-5`)

### Session Detection

Instead of a naive rolling 5-hour window, the app detects actual session boundaries:

1. Scan entries from the last 10 hours (sorted by timestamp)
2. Walk forward, looking for gaps >= 5 hours between consecutive entries
3. The first entry after the last such gap = session start
4. Session resets at start + 5 hours

Priority: **User-configured reset** > **Auto-detected boundary** > **Rolling 5h fallback**

### Plan Usage Limits

Usage percentages use **internal compute-cost pricing** (not API pricing) to match the official Claude usage page:

```
Usage % = weighted_cost / budget

where weighted_cost uses $15/$75 per MTok for Opus (3x API price)
and budget is plan-specific (e.g., $8/session for Pro)
```

## Data Privacy

- All data is read from local files — no network requests for usage data
- Configuration stored in `UserDefaults` (local to your Mac)
- API keys (if configured for legacy mode) stored in macOS Keychain
- No telemetry, no analytics, no third-party services

## Acknowledgments

- [Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) — Python-based monitor that inspired the compute-cost pricing approach and session block methodology
- Built with Swift, SwiftUI, and macOS native APIs

## License

MIT License
