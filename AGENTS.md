# Signal Agent Workspace Instructions (AGENTS.md)

Welcome! This file provides essential system context, build commands, directory structure, coding standards, and agent descriptions to help AI coding agents work efficiently within this repository.

---

## Project Overview
**Signal** is a macOS menu-bar status light application (compiled as `LSUIElement`, meaning no Dock icon) built in AppKit and SwiftUI. It features:
- A breathing LED icon in the status bar rendering colored circular highlights.
- A tabbed popover displaying active color control configurations (Off, Red, Yellow, Green) and a history panel parsing interactive Claude CLI prompt history from `~/.claude/history.jsonl`.
- A CLI companion target (`sgnl`) that communicates with the main app via macOS `DistributedNotificationCenter`.

---

## Commands & Targets
Always use the following executable commands for development:

- **Build Target**: `make build` (Compiles release binaries for both targets and packages `.app` bundle under `.build/Signal.app` with ad-hoc code signature).
- **Run Target**: `make run` (Builds and launches the `.app` bundle).
- **Install Target**: `make install` (Copies `.app` to `/Applications` and `sgnl` binary to `~/.local/bin/`).
- **Clean Target**: `make clean` (Cleans SwiftPM cache and removes build directories).

---

## Target Architecture
The workspace contains two SwiftPM target components:

1. **`Signal`** (`Sources/Signal/`) — Menu-bar popover application.
   - `main.swift`: Target entry point.
   - `AppDelegate.swift`: Manages application delegate hooks, icon rendering, and `NSPopover` controls.
   - **`Models/`**: Holds data models (`LightColor.swift`, `ClaudeHistoryModel.swift`).
   - **`ViewModels/`**: Orchestrates view state (`AppViewModel.swift`).
   - **`Views/`**: SwiftUI popover views (`MainView.swift`, `StatusControlView.swift`, `ClaudeHistoryView.swift`, `ClaudeDetailView.swift`).
2. **`sgnl`** (`Sources/sgnl/`) — CLI companion utility.
   - `main.swift`: CLI parser. Broadcasts notifications to status bar target.

### Inter-process Communication (IPC)
The CLI companion posts distributed notifications to control the status bar:
- `com.signal-light.colorChange` (userInfo: `["color": "red"|"yellow"|"green"|"black"]`)
- `com.signal-light.toggleBreathing` (userInfo: `["enabled": "on"|"off"]`)

---

## Development & Code Conventions

### 1. SwiftUI & NSPopover Bounds
- When presenting an `NSPopover` hosted inside an `NSStatusItem`, always set explicit preferred size values on the `NSHostingController` and the `popover` (`contentSize` / `preferredContentSize`) before rendering. This prevents AppKit layout race conditions from throwing popovers off-screen.
- Set preferred edge to `.minY` to anchor the popover downwards below the menu bar.

### 2. Multi-Threading & File Access
- Perform disk IO (like reading `~/.claude/history.jsonl` files) asynchronously on a global background queue (`DispatchQueue.global(qos: .userInitiated)`).
- Always bounce UI mutations back to the main thread (`DispatchQueue.main.async`).

### 3. Git Commit Message Formats
Commits must include the standard scope details and AI metadata footer:
```text
<type>(<scope>): <subject>

<body>

AI-Generated-By: <Agent Name>
AI-Model: <Model Name>
AI-Agent: <Collaborating Agents, or N/A>
AI-Skill: <Target Skill, or N/A>
```

---

## Available Custom Agents
The repository contains custom agent rules defined under `.claude/agents/`:

- **`oss-architect`**: Evaluates system design, structure, and pattern compliance.
- **`oss-architect-reviewer`**: Reviews and validates architectural proposals.
- **`oss-ops-engineer`**: Coordinates Makefile compilation, build system commands, and deployment scripts.
- **`oss-product-manager`**: Oversees feature scoping, changelogs, and target goals.
- **`oss-qa-engineer`**: Advises on validation coverage and manual test plans.
- **`planner`**: Organizes task tracking and checklist verification.
- **`security-reviewer`**: Focuses on secure boundary validation and vulnerability hardening.
