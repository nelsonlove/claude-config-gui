import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    var body: some View {
        @Bindable var appState = appState
        let settings = Binding(
            get: { self.editor.settings },
            set: { self.editor.settings = $0; self.editor.markDirty() }
        )

        Form {
            Section("Model") {
                TextField("Model ID", text: optionalString(settings.model))
                    .help("Override default model (e.g. claude-sonnet-4-6)")

                OptionalPicker("Effort Level", selection: settings.effortLevel) {
                    ForEach(EffortLevel.allCases) { level in
                        Text(level.rawValue.capitalized).tag(Optional(level))
                    }
                }

                OptionalToggle("Fast Mode", isOn: settings.fastMode)
                OptionalToggle("Always Thinking", isOn: settings.alwaysThinkingEnabled)
            }

            Section("Voice & Updates") {
                OptionalToggle("Voice Enabled", isOn: settings.voiceEnabled)

                OptionalPicker("Updates Channel", selection: settings.autoUpdatesChannel) {
                    ForEach(UpdateChannel.allCases) { ch in
                        Text(ch.rawValue.capitalized).tag(Optional(ch))
                    }
                }
            }

            Section("Display") {
                TextField("Output Style", text: optionalString(settings.outputStyle))
                TextField("Language", text: optionalString(settings.language))

                OptionalPicker("Default View", selection: settings.defaultView) {
                    ForEach(DefaultView.allCases) { v in
                        Text(v.rawValue.capitalized).tag(Optional(v))
                    }
                }

                OptionalPicker("View Mode", selection: settings.viewMode) {
                    ForEach(ViewMode.allCases) { v in
                        Text(v.rawValue.capitalized).tag(Optional(v))
                    }
                }

                OptionalPicker("TUI Mode", selection: settings.tui) {
                    ForEach(TUIMode.allCases) { v in
                        Text(v.rawValue.capitalized).tag(Optional(v))
                    }
                }

                OptionalToggle("Syntax Highlighting", isOn: invertedOptional(settings.syntaxHighlightingDisabled))
                OptionalToggle("Spinner Tips", isOn: settings.spinnerTipsEnabled)
                OptionalToggle("Thinking Summaries", isOn: settings.showThinkingSummaries)
                OptionalToggle("Prompt Suggestions", isOn: settings.promptSuggestionEnabled)
                OptionalToggle("Reduced Motion", isOn: settings.prefersReducedMotion)
            }

            Section("Session") {
                HStack {
                    Text("Cleanup Period")
                    Spacer()
                    TextField("Days", value: settings.cleanupPeriodDays, format: .number)
                        .frame(width: 60)
                    Text("days")
                        .foregroundStyle(.secondary)
                }

                OptionalToggle("Auto Memory", isOn: settings.autoMemoryEnabled)
                OptionalToggle("Auto Dream", isOn: settings.autoDreamEnabled)
                OptionalToggle("Away Summary", isOn: settings.awaySummaryEnabled)
                OptionalToggle("Respect .gitignore", isOn: settings.respectGitignore)
                OptionalToggle("Channels", isOn: settings.channelsEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Binding helpers for optional values

/// Bridges an optional String binding to a non-optional one (empty string = nil).
func optionalString(_ binding: Binding<String?>) -> Binding<String> {
    Binding(
        get: { binding.wrappedValue ?? "" },
        set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }
    )
}

/// Inverts an optional Bool binding (for "disable X" → "enable X" display).
func invertedOptional(_ binding: Binding<Bool?>) -> Binding<Bool?> {
    Binding(
        get: { binding.wrappedValue.map { !$0 } },
        set: { binding.wrappedValue = $0.map { !$0 } }
    )
}
