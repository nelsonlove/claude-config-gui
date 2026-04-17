import SwiftUI

struct AdvancedSettingsView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    var body: some View {
        let settings = editor.settingsBinding

        Form {
            Section("Shell & Git") {
                OptionalPicker("Default Shell", selection: settings.defaultShell) {
                    ForEach(ShellType.allCases) { s in
                        Text(s.rawValue).tag(Optional(s))
                    }
                }
                .described("Shell for ! prefix commands. Bash on macOS/Linux.")
                OptionalToggle("Include Git Instructions", isOn: settings.includeGitInstructions)
                    .described("Adds git workflow guidance to the system prompt. Disable if you manage git yourself.")
            }

            Section("Attribution") {
                let attribution = Binding(
                    get: { settings.wrappedValue.attribution ?? Attribution() },
                    set: { settings.wrappedValue.attribution = $0 }
                )
                TextField("Commit Message", text: optionalString(attribution.commit), prompt: Text("e.g. Co-authored-by: Claude"))
                    .described("Custom text appended to git commit messages.")
                TextField("PR Description", text: optionalString(attribution.pr), prompt: Text("e.g. Generated with Claude"))
                    .described("Custom text appended to pull request descriptions.")
            }

            Section("Status Line") {
                let statusLine = Binding(
                    get: { settings.wrappedValue.statusLine ?? StatusLineConfig() },
                    set: { settings.wrappedValue.statusLine = $0 }
                )
                TextField("Command", text: optionalString(statusLine.command), prompt: Text("e.g. bash ~/.claude/statusline.sh"))
                    .font(.system(.body, design: .monospaced))
                    .described("Shell command whose stdout becomes the status line text.")
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
                TextField("API Key Helper", text: optionalString(settings.apiKeyHelper), prompt: Text("/path/to/auth-script"))
                    .described("Path to a script that outputs API authentication values.")

                OptionalPicker("Force Login Method", selection: settings.forceLoginMethod) {
                    ForEach(LoginMethod.allCases) { m in
                        Text(m.rawValue).tag(Optional(m))
                    }
                }
                .described("claudeai: OAuth via claude.ai. console: Anthropic Console API keys.")

                TextField("Force Login Org UUID", text: optionalString(settings.forceLoginOrgUUID), prompt: Text("org-uuid-here"))
                    .described("Lock login to a specific organization for SSO/enterprise setups.")
            }

            Section("MCP") {
                OptionalToggle("Auto-approve Project MCP Servers", isOn: settings.enableAllProjectMcpServers)
                    .described("Skip the approval prompt for MCP servers defined in project .mcp.json files.")
            }

            Section("Dangerous") {
                OptionalToggle("Skip Bypass-Mode Prompt", isOn: settings.skipDangerousModePermissionPrompt)
                    .described("Skips the confirmation when entering bypass permissions mode.")
                OptionalToggle("Disable All Hooks", isOn: settings.disableAllHooks)
                    .described("Completely disables all hooks and the status line. Useful for debugging.")
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
