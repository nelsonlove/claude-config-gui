import SwiftUI

struct HooksView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    // All 27 hook event types
    static let allEvents = [
        "PreToolUse", "PostToolUse", "PostToolUseFailure",
        "Notification", "UserPromptSubmit",
        "SessionStart", "SessionEnd",
        "Stop", "StopFailure",
        "SubagentStart", "SubagentStop",
        "PreCompact", "PostCompact",
        "PermissionRequest", "PermissionDenied",
        "Setup", "TeammateIdle",
        "TaskCreated", "TaskCompleted",
        "Elicitation", "ElicitationResult",
        "ConfigChange",
        "WorktreeCreate", "WorktreeRemove",
        "InstructionsLoaded", "CwdChanged", "FileChanged"
    ]

    var body: some View {
        let hooks = editor.settings.hooks ?? [:]
        let configuredEvents = hooks.keys.sorted()
        let unconfiguredEvents = Self.allEvents.filter { !hooks.keys.contains($0) }

        Form {
            if configuredEvents.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Hooks Configured",
                        systemImage: "arrow.triangle.branch",
                        description: Text("Add a hook to respond to Claude Code lifecycle events.")
                    )
                }
            }

            ForEach(configuredEvents, id: \.self) { event in
                HookEventSection(
                    event: event,
                    groups: hooks[event] ?? [],
                    onUpdate: { newGroups in
                        updateHook(event: event, groups: newGroups)
                    },
                    onDelete: {
                        deleteHook(event: event)
                    }
                )
            }

            Section {
                Menu("Add Event Hook...") {
                    ForEach(unconfiguredEvents, id: \.self) { event in
                        Button(event) {
                            addHook(event: event)
                        }
                    }
                }
                .disabled(unconfiguredEvents.isEmpty)
            } header: {
                Text("Add Hook")
            } footer: {
                Text("Hooks run shell commands, HTTP requests, prompts, or agents in response to Claude Code lifecycle events. Evaluation order: deny > ask > allow.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func updateHook(event: String, groups: [HookGroup]) {
        var hooks = editor.settings.hooks ?? [:]
        hooks[event] = groups
        editor.settings.hooks = hooks
        editor.markDirty()
    }

    private func deleteHook(event: String) {
        var hooks = editor.settings.hooks ?? [:]
        hooks.removeValue(forKey: event)
        if hooks.isEmpty { editor.settings.hooks = nil }
        else { editor.settings.hooks = hooks }
        editor.markDirty()
    }

    private func addHook(event: String) {
        var hooks = editor.settings.hooks ?? [:]
        let newGroup = HookGroup(
            hooks: [HookHandler(type: .command, command: "echo 'hello'")]
        )
        hooks[event] = [newGroup]
        editor.settings.hooks = hooks
        editor.markDirty()
    }
}

// MARK: - Single hook event section

struct HookEventSection: View {
    let event: String
    let groups: [HookGroup]
    let onUpdate: ([HookGroup]) -> Void
    let onDelete: () -> Void

    var body: some View {
        Section {
            ForEach(Array(groups.enumerated()), id: \.element.id) { groupIdx, group in
                VStack(alignment: .leading, spacing: 8) {
                    if let matcher = group.matcher {
                        HStack {
                            Text("Matcher:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(matcher)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }

                    ForEach(Array((group.hooks ?? []).enumerated()), id: \.element.id) { handlerIdx, handler in
                        HookHandlerRow(handler: handler) { updated in
                            var newGroups = groups
                            var newGroup = newGroups[groupIdx]
                            var handlers = newGroup.hooks ?? []
                            handlers[handlerIdx] = updated
                            newGroup.hooks = handlers
                            newGroups[groupIdx] = newGroup
                            onUpdate(newGroups)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Label(event, systemImage: "bolt.fill")
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Single hook handler row

struct HookHandlerRow: View {
    let handler: HookHandler
    let onUpdate: (HookHandler) -> Void

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                switch handler.type {
                case .command:
                    LabeledTextField("Command", text: binding(\.command))
                    LabeledTextField("Shell", text: binding(\.shell))
                case .http:
                    LabeledTextField("URL", text: binding(\.url))
                case .prompt:
                    LabeledTextField("Prompt", text: binding(\.prompt))
                    LabeledTextField("Model", text: binding(\.model))
                case .agent:
                    LabeledTextField("Prompt", text: binding(\.prompt))
                    LabeledTextField("Model", text: binding(\.model))
                }

                LabeledTextField("If (matcher)", text: binding(\.if))
                    .described("Permission-rule filter, e.g. Bash(git *). Only runs when the tool matches.")
                LabeledTextField("Status Message", text: binding(\.statusMessage))
                    .described("Text shown in the spinner while this hook runs.")

                HStack(spacing: 16) {
                    if let timeout = handler.timeout {
                        Text("Timeout: \(timeout)s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if handler.once == true {
                        Text("Once")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if handler.async == true {
                        Text("Async")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: handlerIcon)
                    .foregroundStyle(.tint)
                    .frame(width: 18)
                Text(handler.type.rawValue)
                    .font(.system(.body, design: .monospaced))
                Text(handlerSummary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private var handlerIcon: String {
        switch handler.type {
        case .command: "terminal"
        case .http: "globe"
        case .prompt: "text.bubble"
        case .agent: "person.2"
        }
    }

    private var handlerSummary: String {
        switch handler.type {
        case .command: handler.command ?? ""
        case .http: handler.url ?? ""
        case .prompt: handler.prompt.map { String($0.prefix(50)) } ?? ""
        case .agent: handler.prompt.map { String($0.prefix(50)) } ?? ""
        }
    }

    private func binding(_ keyPath: WritableKeyPath<HookHandler, String?>) -> Binding<String> {
        Binding(
            get: { handler[keyPath: keyPath] ?? "" },
            set: { newValue in
                var updated = handler
                updated[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
                onUpdate(updated)
            }
        )
    }
}

// MARK: - Helper

struct LabeledTextField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            TextField(label, text: $text)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
        }
    }
}
