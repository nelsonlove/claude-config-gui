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
        }
    }

    /// Group sections for sidebar display
    var group: SectionGroup {
        switch self {
        case .general, .permissions, .hooks, .plugins, .sandbox, .advanced:
            return .settings
        case .claudeMd, .memory:
            return .knowledge
        }
    }

    enum SectionGroup: String, CaseIterable {
        case settings = "Settings"
        case knowledge = "Knowledge"
    }
}
