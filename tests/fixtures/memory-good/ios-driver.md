---
name: ios-driver
description: which driver reaches the iOS Simulator, and the Xcode setting that blocks the other one
metadata:
  type: project
---
Use the Orca emulator driver for shop-ios; `orca emulator ax --json` returns the tree in under a second.
**Why:** Xcode MCP hangs at `tools/list` until Xcode ▸ Settings ▸ Intelligence ▸ "Allow external agents" is enabled, and a hung MCP burns the whole turn budget.
**How to apply:** try Orca first; if a run must use Xcode MCP, check that setting before anything else.
