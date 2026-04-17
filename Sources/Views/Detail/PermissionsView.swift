import SwiftUI

struct PermissionsView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    var body: some View {
        let settings = editor.settingsBinding

        let permissions = Binding(
            get: { self.editor.settings.permissions ?? Permissions() },
            set: { newValue in self.editor.mutate { $0.permissions = newValue } }
        )

        Form {
            Section("Permission Mode") {
                Picker("Default Mode", selection: permissions.defaultMode) {
                    Text("Not Set").tag(nil as PermissionMode?)
                    ForEach(PermissionMode.allCases) { mode in
                        Text(mode.label).tag(Optional(mode))
                    }
                }
                .described("Default: prompt each tool. Accept Edits: auto-approve file changes. Bypass: skip all prompts. Auto: AI decides. Plan: read-only.")
            }

            PermissionRulesList(
                title: "Allow Rules",
                help: "Auto-approved without prompting. Evaluated after deny rules. Syntax: Tool or Tool(specifier), e.g. Bash(npm run *)",
                rules: Binding(
                    get: { permissions.wrappedValue.allow ?? [] },
                    set: { permissions.wrappedValue.allow = $0.isEmpty ? nil : $0 }
                )
            )

            PermissionRulesList(
                title: "Deny Rules",
                help: "Always blocked. Takes highest priority — evaluated before allow and ask.",
                rules: Binding(
                    get: { permissions.wrappedValue.deny ?? [] },
                    set: { permissions.wrappedValue.deny = $0.isEmpty ? nil : $0 }
                )
            )

            PermissionRulesList(
                title: "Ask Rules",
                help: "Always prompts for confirmation, even in auto mode.",
                rules: Binding(
                    get: { permissions.wrappedValue.ask ?? [] },
                    set: { permissions.wrappedValue.ask = $0.isEmpty ? nil : $0 }
                )
            )

            StringListEditor(
                title: "Additional Directories",
                help: "Extra directories Claude can access beyond the project root.",
                items: Binding(
                    get: { permissions.wrappedValue.additionalDirectories ?? [] },
                    set: { permissions.wrappedValue.additionalDirectories = $0.isEmpty ? nil : $0 }
                ),
                placeholder: "../other-project/"
            )
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Permission Rules List

struct PermissionRulesList: View {
    let title: String
    var help: String? = nil
    @Binding var rules: [String]
    @State private var newRule = ""

    var body: some View {
        Section {
            ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                HStack {
                    Image(systemName: ruleValidation(rule) != nil ? "exclamationmark.triangle.fill" : ruleIcon(for: rule))
                        .foregroundColor(ruleValidation(rule) != nil ? .red : .secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule)
                            .font(.system(.body, design: .monospaced))
                        if let warning = ruleValidation(rule) {
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    Button(role: .destructive) {
                        rules.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.green)
                    .frame(width: 20)
                TextField("e.g. Bash(npm run *)", text: $newRule)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        addRule()
                    }
                Button("Add") {
                    addRule()
                }
                .disabled(newRule.isEmpty)
            }

            if rules.isEmpty {
                Text("No rules configured")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        } header: {
            Text(title)
        } footer: {
            if let help {
                Text(help)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addRule() {
        let trimmed = newRule.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        rules.append(trimmed)
        newRule = ""
    }

    private func ruleIcon(for rule: String) -> String {
        if rule.hasPrefix("Bash") { return "terminal" }
        if rule.hasPrefix("Read") { return "doc" }
        if rule.hasPrefix("Edit") || rule.hasPrefix("Write") { return "pencil" }
        if rule.hasPrefix("WebFetch") || rule.hasPrefix("WebSearch") { return "globe" }
        if rule.hasPrefix("mcp_") { return "server.rack" }
        if rule.hasPrefix("Agent") { return "person.2" }
        return "lock"
    }

    /// Returns a warning message if the rule looks malformed, nil if valid.
    private func ruleValidation(_ rule: String) -> String? {
        let knownTools = [
            "Bash", "Read", "Edit", "Write", "Glob", "Grep",
            "WebFetch", "WebSearch", "Agent", "Skill",
            "NotebookEdit", "NotebookRead", "LSP"
        ]

        // Check for unbalanced parens
        let opens = rule.filter { $0 == "(" }.count
        let closes = rule.filter { $0 == ")" }.count
        if opens != closes {
            return "Unbalanced parentheses"
        }

        // Extract the tool name (before "(" or the whole string)
        let toolName: String
        if let parenIdx = rule.firstIndex(of: "(") {
            toolName = String(rule[rule.startIndex..<parenIdx])
        } else {
            toolName = rule
        }

        // MCP tools use mcp__ prefix
        if toolName.hasPrefix("mcp__") || toolName.hasPrefix("mcp_") {
            return nil
        }

        // Check against known tool names
        if !knownTools.contains(toolName) && !toolName.isEmpty {
            return "Unknown tool: \(toolName)"
        }

        return nil
    }
}

// MARK: - Reusable String List Editor

struct StringListEditor: View {
    let title: String
    var help: String? = nil
    @Binding var items: [String]
    var placeholder: String = ""
    @State private var newItem = ""

    var body: some View {
        Section {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(role: .destructive) {
                        items.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField(placeholder, text: $newItem)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addItem() }
                Button("Add") { addItem() }
                    .disabled(newItem.isEmpty)
            }
        } header: {
            Text(title)
        } footer: {
            if let help {
                Text(help)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        items.append(trimmed)
        newItem = ""
    }
}
