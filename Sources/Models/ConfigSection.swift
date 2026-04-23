import SwiftUI

enum ConfigSection: String, CaseIterable, Identifiable {
    case general
    case permissions
    case hooks
    case plugins
    case sandbox
    case advanced
    case claudeMd
    case memory
    case mcpServers
    case sessions
    case analytics
    case fileHistory
    case diskUsage

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .permissions: "Permissions"
        case .hooks: "Hooks"
        case .plugins: "Plugins"
        case .sandbox: "Sandbox"
        case .advanced: "Advanced"
        case .claudeMd: "CLAUDE.md"
        case .memory: "Memory"
        case .mcpServers: "MCP Servers"
        case .sessions: "Sessions"
        case .analytics: "Analytics"
        case .fileHistory: "File History"
        case .diskUsage: "Disk Usage"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .permissions: "lock.shield"
        case .hooks: "arrow.triangle.branch"
        case .plugins: "puzzlepiece.extension"
        case .sandbox: "shield.lefthalf.filled"
        case .advanced: "wrench.and.screwdriver"
        case .claudeMd: "doc.text"
        case .memory: "brain.head.profile"
        case .mcpServers: "server.rack"
        case .sessions: "bubble.left.and.bubble.right"
        case .analytics: "chart.bar"
        case .fileHistory: "clock.arrow.circlepath"
        case .diskUsage: "internaldrive"
        }
    }

    var description: String {
        switch self {
        case .general: "Model, effort level, voice, and display settings"
        case .permissions: "Tool access rules and permission modes"
        case .hooks: "Lifecycle event handlers"
        case .plugins: "Installed plugins and marketplaces"
        case .sandbox: "Filesystem and network sandboxing"
        case .advanced: "Environment, attribution, and shell settings"
        case .claudeMd: "Global and project conventions"
        case .memory: "Persistent memory across sessions"
        case .mcpServers: "External tool integrations"
        case .sessions: "Browse and search past sessions"
        case .analytics: "Session stats and usage trends"
        case .fileHistory: "Browse file snapshots from sessions"
        case .diskUsage: "Storage breakdown of ~/.claude"
        }
    }

    /// Group sections for sidebar display
    var group: SectionGroup {
        switch self {
        case .general, .permissions, .hooks, .plugins, .sandbox, .advanced:
            return .settings
        case .claudeMd, .memory:
            return .knowledge
        case .mcpServers:
            return .integrations
        case .sessions, .analytics, .fileHistory, .diskUsage:
            return .system
        }
    }

    enum SectionGroup: String, CaseIterable {
        case settings = "Settings"
        case knowledge = "Knowledge"
        case integrations = "Integrations"
        case system = "System"
    }
}
