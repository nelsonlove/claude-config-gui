# Claude Config GUI

A native macOS app for managing [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration visually.

Built with SwiftUI, targeting macOS 14+ (Sonoma).

## Features

### Settings Editor
- **6 panels**: General, Permissions, Hooks, Plugins, Sandbox, Advanced
- **Scope switcher**: User / Project / Local with project picker
- **Inherited values**: shows parent scope settings as ghost indicators
- **Permission validation**: warns about malformed rule syntax
- **Raw JSON toggle**: switch between form editor and raw JSON
- **Undo/redo** and **Cmd+S** to force save
- **Auto-save**: debounced 1-second save with file watching for external changes

### CLAUDE.md Editor
- Edit global `~/.claude/CLAUDE.md` or project-scoped `.claude/CLAUDE.md`
- Monospaced text editor with auto-save
- Scope-aware: follows the sidebar scope picker

### Memory Browser
- Browse all memory files across all projects
- Parse and edit YAML frontmatter (name, description, type)
- Create new memory files with proper frontmatter
- Delete memory entries

### MCP Servers
- Visual editor for MCP server configurations
- Three scopes: User (`~/.claude.json`), Project (`.mcp.json`), Local (`claude_desktop_config.json`)
- Transport type picker: stdio, SSE, HTTP, WebSocket
- Command + args + env builder for stdio servers
- Read-only view of plugin-provided MCP servers

### Session Browser
- Browse all past sessions with search
- Full transcript viewer with collapsible tool calls
- Tool call details: input parameters and results
- Falls back to history.jsonl when transcripts are cleaned up
- Filter by project when project scope is active
- Delete sessions (removes transcript, analytics, and history)

### Analytics Dashboard
- Session count, total hours, token usage, git commits
- Tool usage bar chart
- Language breakdown
- Recent sessions list

### Disk Usage
- Storage breakdown of every `~/.claude/` subdirectory
- Cleanup actions: delete debug logs, shell snapshots, file history, cache

## Building

Requires:
- macOS 14+ (Sonoma)
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```bash
# Generate Xcode project
xcodegen generate

# Build and run
xcodebuild -project ClaudeConfigGUI.xcodeproj \
  -scheme ClaudeConfigGUI \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  build

# Launch
open build/Build/Products/Debug/Claude\ Config.app

# Or open in Xcode
open ClaudeConfigGUI.xcodeproj
```

## Architecture

- **SwiftUI** with `@Observable` view models (Swift 5.9+)
- **`NavigationSplitView`** sidebar + detail, System Settings style
- **No App Sandbox** — needs direct access to `~/.claude/`
- **No SwiftData** — plain `Codable` + `FileManager` for JSON files
- **Debounced auto-save** with `DispatchSource` file watching
- **macOS HIG**: checkboxes, `.formStyle(.grouped)`, `.subheadline` descriptions

## Project Structure

```
Sources/
  App/           Entry point, ContentView, Assets
  Models/        ClaudeSettings, MemoryEntry, SessionHistory, MCPConfig, etc.
  ViewModels/    AppState, ConfigEditor, MarkdownFileEditor, MCPConfigEditor
  Views/
    Sidebar/     SidebarView, DetailView (router)
    Detail/      One view per section (GeneralSettingsView, HooksView, etc.)
    Components/  OptionalToggle, OptionalPicker, OptionalStepper, etc.
```

## License

MIT
