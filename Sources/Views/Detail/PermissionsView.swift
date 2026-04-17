import SwiftUI

struct PermissionsView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    var body: some View {
        let settings = Binding(
            get: { self.editor.settings },
            set: { self.editor.settings = $0; self.editor.markDirty() }
        )

        let permissions = Binding(
            get: { self.editor.settings.permissions ?? Permissions() },
            set: { self.editor.settings.permissions = $0; self.editor.markDirty() }
        )

        Form {
            Section("Permission Mode") {
                Picker("Default Mode", selection: permissions.defaultMode) {
                    Text("Not Set").tag(nil as PermissionMode?)
                    ForEach(PermissionMode.allCases) { mode in
                        Text(mode.label).tag(Optional(mode))
                    }
                }
                .help("Controls how Claude asks for tool permissions")
            }

            PermissionRulesList(title: "Allow Rules", rules: Binding(
                get: { permissions.wrappedValue.allow ?? [] },
                set: { permissions.wrappedValue.allow = $0.isEmpty ? nil : $0 }
            ))

            PermissionRulesList(title: "Deny Rules", rules: Binding(
                get: { permissions.wrappedValue.deny ?? [] },
                set: { permissions.wrappedValue.deny = $0.isEmpty ? nil : $0 }
            ))

            PermissionRulesList(title: "Ask Rules", rules: Binding(
                get: { permissions.wrappedValue.ask ?? [] },
                set: { permissions.wrappedValue.ask = $0.isEmpty ? nil : $0 }
            ))

            StringListEditor(
                title: "Additional Directories",
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
    @Binding var rules: [String]
    @State private var newRule = ""

    var body: some View {
        Section(title) {
            ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                HStack {
                    Image(systemName: ruleIcon(for: rule))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(rule)
                        .font(.system(.body, design: .monospaced))
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
}

// MARK: - Reusable String List Editor

struct StringListEditor: View {
    let title: String
    @Binding var items: [String]
    var placeholder: String = ""
    @State private var newItem = ""

    var body: some View {
        Section(title) {
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
        }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        items.append(trimmed)
        newItem = ""
    }
}
