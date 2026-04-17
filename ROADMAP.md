# Claude Config GUI — Roadmap

SwiftUI macOS app for managing Claude Code CLI configuration (`~/.claude/`).

## Architecture

- **Platform**: macOS 14+ (Sonoma), Swift 5.9+
- **UI**: NavigationSplitView (sidebar + detail), System Settings style
- **State**: `@Observable` view models, plain `Codable` structs for JSON
- **Persistence**: Direct `FileManager` reads/writes to `~/.claude/` (no sandbox, no SwiftData)
- **Save strategy**: Debounced auto-save (1s) with `DispatchSource` file watching for external changes
- **Distribution**: Non-App Store, Developer ID + notarization when ready

## Phase 1: Settings Editor (current)

Core `settings.json` viewer/editor.

### Panels
- [x] **General** — model, effortLevel, fastMode, voiceEnabled, autoUpdatesChannel, display settings, session settings
- [x] **Permissions** — allow/deny/ask rule list editors, defaultMode picker, additionalDirectories
- [x] **Hooks** — 27 event types, hook groups with matchers, 4 handler types (command/http/prompt/agent)
- [x] **Plugins** — enabledPlugins toggles, marketplace viewer
- [x] **Sandbox** — filesystem allow/deny paths, network domains, excluded commands
- [x] **Advanced** — env vars, attribution, statusLine, authentication, MCP, shell/git settings

### Infrastructure
- [x] Scope switcher (User / Project / Local) in sidebar
- [x] Codable models covering full settings.json schema
- [x] ConfigEditor with debounced auto-save
- [x] DispatchSource file watching for external changes
- [x] Status bar showing save state and file path
- [x] AnyCodableValue for dynamic JSON sections

### TODO — Phase 1 polish
- [x] Toolbar save/reload buttons
- [x] JSON raw editor tab (toggle between form and raw JSON)
- [x] Keyboard shortcuts (Cmd+S save, Cmd+Z undo, Cmd+Shift+Z redo)
- [x] Validation (permission rule syntax checking with warning icons)
- [x] Undo/redo via UndoManager (snapshot-based, registered on each mutation)
- [ ] Merged/effective config read-only view (show what Claude actually sees)

## Phase 2: CLAUDE.md & Memory

- [ ] Markdown editor for `~/.claude/CLAUDE.md` and project `.claude/CLAUDE.md`
- [ ] Memory browser: list/view/edit/delete files in `projects/*/memory/`
- [ ] Memory frontmatter editor (name, description, type fields)
- [ ] Project picker (enumerate `~/.claude/projects/*/`)
- [ ] Split-pane preview (edit left, rendered markdown right)

## Phase 3: MCP Servers

- [ ] Visual editor for `~/.claude.json` (user MCP config)
- [ ] Visual editor for `.mcp.json` (project MCP config)
- [ ] Transport type picker (stdio / sse / http / ws + IDE variants)
- [ ] Command + args + env builder for stdio servers
- [ ] Server approval status from settings.json (`enabledMcpjsonServers` / `disabledMcpjsonServers`)
- [ ] Test connection button (launch server, check for handshake)

## Phase 4: Analytics & Housekeeping

- [ ] Session stats dashboard (read `usage-data/facets/*.json` and `session-meta/*.json`)
  - Token usage over time
  - Tool usage breakdown
  - Session duration and satisfaction trends
- [ ] Session history browser (`history.jsonl`)
- [ ] File history viewer (`file-history/`)
- [ ] Debug log browser and cleanup
- [ ] Session pruning (honor `cleanupPeriodDays`)
- [ ] Disk usage summary

## Phase 5: Polish & Distribution

- [ ] Full file watching with FSEvents for directory tree changes
- [ ] Backup before destructive edits (automatic `.bak` or timestamped copies)
- [ ] Export/import settings bundles (share configs between machines)
- [ ] App icon and branding
- [ ] Sparkle integration for auto-updates (or manual update check)
- [ ] Developer ID code signing
- [ ] Notarization for Gatekeeper-friendly distribution
- [ ] DMG/zip packaging
- [ ] README with screenshots

## Non-goals

- Not a session/chat interface (OpCode covers that)
- Not a plugin development environment
- Not an MCP server runtime — just config editing
- No iOS/iPadOS version planned
