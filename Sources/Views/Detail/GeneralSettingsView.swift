import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    var body: some View {
        @Bindable var appState = appState
        let settings = editor.settingsBinding

        Form {
            Section("Model") {
                TextField("Model ID", text: optionalString(settings.model), prompt: Text("e.g. claude-sonnet-4-6"))
                    .described("Override the default model.")

                OptionalPicker("Effort Level", selection: settings.effortLevel) {
                    ForEach(EffortLevel.allCases) { level in
                        Text(level.rawValue.capitalized).tag(Optional(level))
                    }
                }
                .described("Low is faster but less thorough. High uses extended thinking.")

                OptionalToggle("Fast Mode", isOn: settings.fastMode)
                    .described("Same model, optimized for faster output. Toggle with /fast.")
                OptionalToggle("Always Thinking", isOn: settings.alwaysThinkingEnabled)
                    .described("Extended thinking by default — Claude reasons step-by-step before responding.")
            }

            Section("Voice & Updates") {
                OptionalToggle("Voice Enabled", isOn: settings.voiceEnabled)
                    .described("Speak prompts instead of typing.")

                OptionalPicker("Updates Channel", selection: settings.autoUpdatesChannel) {
                    ForEach(UpdateChannel.allCases) { ch in
                        Text(ch.rawValue.capitalized).tag(Optional(ch))
                    }
                }
                .described("Stable: tested releases. Latest: bleeding-edge updates.")
            }

            Section("Display") {
                TextField("Output Style", text: optionalString(settings.outputStyle), prompt: Text("e.g. explanatory, concise"))
                    .described("Named style controlling response formatting.")
                TextField("Language", text: optionalString(settings.language), prompt: Text("e.g. en, ja, es"))
                    .described("Preferred language for responses and voice.")

                OptionalPicker("Default View", selection: settings.defaultView) {
                    ForEach(DefaultView.allCases) { v in
                        Text(v.rawValue.capitalized).tag(Optional(v))
                    }
                }
                .described("Chat: conversational. Transcript: full tool-call log.")

                OptionalPicker("View Mode", selection: settings.viewMode) {
                    ForEach(ViewMode.allCases) { v in
                        Text(v.label).tag(Optional(v))
                    }
                }
                .described("Normal: standard output. Verbose: more detail. Focus: hides tool calls.")

                OptionalPicker("TUI Mode", selection: settings.tui) {
                    ForEach(TUIMode.allCases) { v in
                        Text(v.label).tag(Optional(v))
                    }
                }
                .described("Fullscreen: alternate terminal buffer (like vim). Inline: renders in place.")

                OptionalToggle("Syntax Highlighting", isOn: invertedOptional(settings.syntaxHighlightingDisabled))
                    .described("Colored syntax highlighting in code diffs.")
                OptionalToggle("Spinner Tips", isOn: settings.spinnerTipsEnabled)
                    .described("Shows helpful tips while Claude is thinking.")
                OptionalToggle("Thinking Summaries", isOn: settings.showThinkingSummaries)
                    .described("Shows Claude's reasoning in the transcript. Toggle with Ctrl+O.")
                OptionalToggle("Prompt Suggestions", isOn: settings.promptSuggestionEnabled)
                    .described("Suggested follow-up prompts after each response.")
                OptionalToggle("Reduced Motion", isOn: settings.prefersReducedMotion)
                    .described("Disables spinner and other animations for accessibility.")
            }

            Section("Session") {
                OptionalStepper(
                    "Cleanup Period",
                    value: settings.cleanupPeriodDays,
                    range: 0...365,
                    unit: "days"
                )
                .described("Days to retain transcripts. Default 30. Set 0 to disable persistence.")

                OptionalToggle("Auto Memory", isOn: settings.autoMemoryEnabled)
                    .described("Saves learned preferences and patterns for future sessions.")
                OptionalToggle("Auto Dream", isOn: settings.autoDreamEnabled)
                    .described("Background memory consolidation between sessions.")
                OptionalToggle("Away Summary", isOn: settings.awaySummaryEnabled)
                    .described("Shows a recap when you return after being away.")
                OptionalToggle("Respect .gitignore", isOn: settings.respectGitignore)
                    .described("File picker and @ autocomplete skip .gitignore-matched files.")
                OptionalToggle("Channels", isOn: settings.channelsEnabled)
                    .described("Plugin channel notifications for real-time updates.")
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
