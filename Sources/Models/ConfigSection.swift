import SwiftUI

enum ConfigSection: String, CaseIterable, Identifiable {
    case general
    case permissions
    case hooks
    case plugins
    case sandbox
    case advanced

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .permissions: "Permissions"
        case .hooks: "Hooks"
        case .plugins: "Plugins"
        case .sandbox: "Sandbox"
        case .advanced: "Advanced"
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
        }
    }
}
