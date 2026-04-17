import SwiftUI

struct AdvancedSettingsView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    var body: some View {
        let settings = Binding(
            get: { self.editor.settings },
            set: { self.editor.settings = $0; self.editor.markDirty() }
        )

        Form {
            Section("Shell & Git") {
                OptionalPicker("Default Shell", selection: settings.defaultShell) {
                    ForEach(ShellType.allCases) { s in
                        Text(s.rawValue).tag(Optional(s))
                    }
                }
                .help("Shell used for ! prefix commands. Bash on macOS/Linux, PowerShell on Windows.")
                OptionalToggle("Include Git Instructions", isOn: settings.includeGitInstructions)
                    .help("Includes git workflow guidance in Claude's system prompt. Disable if you manage git yourself.")
            }

            Section("Attribution") {
                let attribution = Binding(
                    get: { settings.wrappedValue.attribution ?? Attribution() },
                    set: { settings.wrappedValue.attribution = $0 }
                )
                TextField("Commit Message", text: optionalString(attribution.commit))
                    .help("Custom attribution text for git commits")
                TextField("PR Description", text: optionalString(attribution.pr))
                    .help("Custom attribution text for pull requests")
            }

            Section("Status Line") {
                let statusLine = Binding(
                    get: { settings.wrappedValue.statusLine ?? StatusLineConfig() },
                    set: { settings.wrappedValue.statusLine = $0 }
                )
                TextField("Command", text: optionalString(statusLine.command))
                    .font(.system(.body, design: .monospaced))
                    .help("Shell command that outputs the status line text")
            }

            Section("Environment Variables") {
                let env = Binding(
                    get: { settings.wrappedValue.env ?? [:] },
                    set: { settings.wrappedValue.env = $0.isEmpty ? nil : $0 }
                )

                ForEach(env.wrappedValue.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text(key)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 150, alignment: .leading)
                        Text("=")
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            var newEnv = env.wrappedValue
                            newEnv.removeValue(forKey: key)
                            env.wrappedValue = newEnv
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                EnvVarAdder(env: env)
            }

            Section("Authentication") {
                TextField("API Key Helper", text: optionalString(settings.apiKeyHelper))
                    .help("Path to script that outputs API authentication values")

                OptionalPicker("Force Login Method", selection: settings.forceLoginMethod) {
                    ForEach(LoginMethod.allCases) { m in
                        Text(m.rawValue).tag(Optional(m))
                    }
                }
                .help("\"claudeai\" uses claude.ai OAuth; \"console\" uses Anthropic Console API keys.")

                TextField("Force Login Org UUID", text: optionalString(settings.forceLoginOrgUUID))
                    .help("Lock login to a specific organization. Used with SSO/enterprise setups.")
            }

            Section("MCP") {
                OptionalToggle("Auto-approve Project MCP Servers", isOn: settings.enableAllProjectMcpServers)
                    .help("Automatically approve all MCP servers defined in project .mcp.json files without prompting.")
            }

            Section("Dangerous") {
                OptionalToggle("Skip Bypass-Mode Prompt", isOn: settings.skipDangerousModePermissionPrompt)
                    .help("Skips the confirmation dialog when entering bypass permissions mode. Use with caution.")
                OptionalToggle("Disable All Hooks", isOn: settings.disableAllHooks)
                    .help("Completely disables all hooks and the status line. Useful for debugging hook issues.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct EnvVarAdder: View {
    @Binding var env: [String: String]
    @State private var newKey = ""
    @State private var newValue = ""

    var body: some View {
        HStack {
            TextField("KEY", text: $newKey)
                .font(.system(.body, design: .monospaced))
                .frame(width: 150)
            Text("=")
                .foregroundStyle(.secondary)
            TextField("value", text: $newValue)
                .font(.system(.body, design: .monospaced))
                .onSubmit { add() }
            Button("Add") { add() }
                .disabled(newKey.isEmpty)
        }
    }

    private func add() {
        let k = newKey.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return }
        env[k] = newValue
        newKey = ""
        newValue = ""
    }
}
