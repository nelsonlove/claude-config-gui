import Foundation

// MARK: - Top-level settings.json

struct ClaudeSettings: Codable {
    // Model & AI
    var model: String?
    var availableModels: [String]?
    var modelOverrides: [String: String]?
    var advisorModel: String?
    var alwaysThinkingEnabled: Bool?
    var effortLevel: EffortLevel?
    var fastMode: Bool?
    var fastModePerSessionOptIn: Bool?

    // Permissions
    var permissions: Permissions?

    // Hooks
    var hooks: [String: [HookGroup]]?

    // Plugins
    var enabledPlugins: [String: Bool]?
    var extraKnownMarketplaces: [String: MarketplaceConfig]?
    var pluginConfigs: [String: PluginConfig]?

    // Sandbox
    var sandbox: SandboxConfig?

    // UI & Display
    var statusLine: StatusLineConfig?
    var outputStyle: String?
    var language: String?
    var syntaxHighlightingDisabled: Bool?
    var prefersReducedMotion: Bool?
    var spinnerTipsEnabled: Bool?
    var defaultView: DefaultView?
    var showThinkingSummaries: Bool?
    var promptSuggestionEnabled: Bool?
    var tui: TUIMode?
    var viewMode: ViewMode?

    // Git & Attribution
    var attribution: Attribution?
    var includeCoAuthoredBy: Bool?
    var includeGitInstructions: Bool?

    // Session & Behavior
    var cleanupPeriodDays: Int?
    var env: [String: String]?
    var respectGitignore: Bool?
    var agent: String?
    var autoMemoryEnabled: Bool?
    var autoMemoryDirectory: String?
    var autoDreamEnabled: Bool?
    var plansDirectory: String?
    var awaySummaryEnabled: Bool?
    var channelsEnabled: Bool?

    // Voice & Updates
    var voiceEnabled: Bool?
    var autoUpdatesChannel: UpdateChannel?
    var minimumVersion: String?

    // MCP
    var enableAllProjectMcpServers: Bool?
    var enabledMcpjsonServers: [String]?
    var disabledMcpjsonServers: [String]?

    // Auto Mode
    var autoMode: AutoModeConfig?
    var skipAutoPermissionPrompt: Bool?
    var useAutoModeDuringPlan: Bool?

    // Remote
    var remote: RemoteConfig?
    var sshConfigs: [SSHConfig]?

    // Worktree
    var worktree: WorktreeConfig?

    // Auth
    var apiKeyHelper: String?
    var forceLoginMethod: LoginMethod?
    var forceLoginOrgUUID: String?

    // Misc
    var skipDangerousModePermissionPrompt: Bool?
    var defaultShell: ShellType?
    var disableAllHooks: Bool?

    // Enterprise
    var allowManagedHooksOnly: Bool?
    var allowManagedPermissionRulesOnly: Bool?
    var allowManagedMcpServersOnly: Bool?
    var strictPluginOnlyCustomization: StrictPluginCustomization?
}

// MARK: - Enums

enum EffortLevel: String, Codable, CaseIterable, Identifiable {
    case low, medium, high
    var id: Self { self }
}

enum DefaultView: String, Codable, CaseIterable, Identifiable {
    case chat, transcript
    var id: Self { self }
}

enum TUIMode: String, Codable, CaseIterable, Identifiable {
    case fullscreen, `default`
    var id: Self { self }
    var label: String {
        switch self {
        case .fullscreen: "Fullscreen"
        case .default: "Inline"
        }
    }
}

enum ViewMode: String, Codable, CaseIterable, Identifiable {
    case `default`, verbose, focus
    var id: Self { self }
    var label: String {
        switch self {
        case .default: "Normal"
        case .verbose: "Verbose"
        case .focus: "Focus"
        }
    }
}

enum UpdateChannel: String, Codable, CaseIterable, Identifiable {
    case latest, stable
    var id: Self { self }
}

enum LoginMethod: String, Codable, CaseIterable, Identifiable {
    case claudeai, console
    var id: Self { self }
}

enum ShellType: String, Codable, CaseIterable, Identifiable {
    case bash, powershell
    var id: Self { self }
}

enum PermissionMode: String, Codable, CaseIterable, Identifiable {
    case `default`
    case acceptEdits
    case bypassPermissions
    case dontAsk
    case plan
    case auto
    var id: Self { self }

    var label: String {
        switch self {
        case .default: "Default"
        case .acceptEdits: "Accept Edits"
        case .bypassPermissions: "Bypass Permissions"
        case .dontAsk: "Don't Ask"
        case .plan: "Plan"
        case .auto: "Auto"
        }
    }
}

// MARK: - Nested types

struct Permissions: Codable {
    var allow: [String]?
    var deny: [String]?
    var ask: [String]?
    var defaultMode: PermissionMode?
    var additionalDirectories: [String]?
    var disableBypassPermissionsMode: String?
    var disableAutoMode: String?
}

struct HookGroup: Codable, Identifiable {
    var id = UUID()
    var matcher: String?
    var hooks: [HookHandler]?

    enum CodingKeys: String, CodingKey {
        case matcher, hooks
    }
}

struct HookHandler: Codable, Identifiable {
    var id = UUID()
    var type: HookHandlerType
    var command: String?
    var url: String?
    var prompt: String?
    var `if`: String?
    var shell: String?
    var timeout: Int?
    var statusMessage: String?
    var once: Bool?
    var async: Bool?
    var asyncRewake: Bool?
    var model: String?
    var headers: [String: String]?
    var allowedEnvVars: [String]?

    enum CodingKeys: String, CodingKey {
        case type, command, url, prompt, `if`, shell, timeout
        case statusMessage, once, async, asyncRewake, model
        case headers, allowedEnvVars
    }
}

enum HookHandlerType: String, Codable, CaseIterable, Identifiable {
    case command, http, prompt, agent
    var id: Self { self }
}

struct MarketplaceConfig: Codable {
    var source: MarketplaceSource?
    var installLocation: String?
    var autoUpdate: Bool?
}

struct MarketplaceSource: Codable {
    var source: String?
    var repo: String?
    var url: String?
    var ref: String?
    var path: String?
    var package: String?
}

struct PluginConfig: Codable {
    var mcpServers: [String: [String: AnyCodableValue]]?
    var options: [String: AnyCodableValue]?
}

struct SandboxConfig: Codable {
    var enabled: Bool?
    var failIfUnavailable: Bool?
    var autoAllowBashIfSandboxed: Bool?
    var allowUnsandboxedCommands: Bool?
    var excludedCommands: [String]?
    var filesystem: SandboxFilesystem?
    var network: SandboxNetwork?
}

struct SandboxFilesystem: Codable {
    var allowWrite: [String]?
    var denyWrite: [String]?
    var denyRead: [String]?
    var allowRead: [String]?
}

struct SandboxNetwork: Codable {
    var allowedDomains: [String]?
    var allowUnixSockets: [String]?
    var allowAllUnixSockets: Bool?
    var allowLocalBinding: Bool?
    var httpProxyPort: Int?
    var socksProxyPort: Int?
}

struct StatusLineConfig: Codable {
    var type: String?
    var command: String?
    var padding: Int?
}

struct Attribution: Codable {
    var commit: String?
    var pr: String?
}

struct AutoModeConfig: Codable {
    var allow: [String]?
    var soft_deny: [String]?
    var environment: [String]?
}

struct RemoteConfig: Codable {
    var defaultEnvironmentId: String?
}

struct SSHConfig: Codable, Identifiable {
    var id: String
    var name: String?
    var sshHost: String?
    var sshPort: Int?
    var sshIdentityFile: String?
    var startDirectory: String?
}

struct WorktreeConfig: Codable {
    var symlinkDirectories: [String]?
    var sparsePaths: [String]?
}

// Flexible union for strict plugin customization (bool or string array)
enum StrictPluginCustomization: Codable {
    case enabled(Bool)
    case categories([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self = .enabled(bool)
        } else {
            self = .categories(try container.decode([String].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .enabled(let bool): try container.encode(bool)
        case .categories(let arr): try container.encode(arr)
        }
    }
}
