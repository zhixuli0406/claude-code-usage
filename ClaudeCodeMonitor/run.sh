#!/bin/bash

# Quick launch script for Claude Code Monitor

set -e

echo "🚀 Building Claude Code Monitor..."
swift build -c release

echo ""
echo "✅ Build complete!"
echo ""
echo "Starting application..."
echo ""

# Run the application
.build/release/ClaudeCodeMonitor
