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
                .help("Controls how much effort Claude spends on responses. Low is faster but less thorough; High uses extended thinking.")

                OptionalToggle("Fast Mode", isOn: settings.fastMode)
                    .help("Uses the same model but optimizes for faster output speed. Toggle with /fast in the CLI.")
                OptionalToggle("Always Thinking", isOn: settings.alwaysThinkingEnabled)
                    .help("Enables extended thinking by default, letting Claude reason through complex problems step-by-step before responding.")
            }

            Section("Voice & Updates") {
                OptionalToggle("Voice Enabled", isOn: settings.voiceEnabled)
                    .help("Enables voice input mode for speaking prompts instead of typing.")

                OptionalPicker("Updates Channel", selection: settings.autoUpdatesChannel) {
                    ForEach(UpdateChannel.allCases) { ch in
                        Text(ch.rawValue.capitalized).tag(Optional(ch))
                    }
                }
                .help("\"stable\" receives tested releases; \"latest\" gets bleeding-edge updates sooner.")
            }

            Section("Display") {
                TextField("Output Style", text: optionalString(settings.outputStyle))
                    .help("Named output style that controls Claude's response formatting (e.g. \"explanatory\", \"concise\").")
                TextField("Language", text: optionalString(settings.language))
                    .help("Preferred language for Claude's responses and voice transcription (e.g. \"en\", \"ja\", \"es\").")

                OptionalPicker("Default View", selection: settings.defaultView) {
                    ForEach(DefaultView.allCases) { v in
                        Text(v.rawValue.capitalized).tag(Optional(v))
                    }
                }
                .help("\"chat\" shows a conversational view; \"transcript\" shows the full tool-call log.")

                OptionalPicker("View Mode", selection: settings.viewMode) {
                    ForEach(ViewMode.allCases) { v in
                        Text(v.rawValue.capitalized).tag(Optional(v))
                    }
                }
                .help("\"default\" is normal output; \"verbose\" shows more detail; \"focus\" hides tool calls for a cleaner view.")

                OptionalPicker("TUI Mode", selection: settings.tui) {
                    ForEach(TUIMode.allCases) { v in
                        Text(v.rawValue.capitalized).tag(Optional(v))
                    }
                }
                .help("\"fullscreen\" uses an alternate terminal buffer (like vim); \"default\" renders inline.")

                OptionalToggle("Syntax Highlighting", isOn: invertedOptional(settings.syntaxHighlightingDisabled))
                    .help("Enables colored syntax highlighting in code diffs shown in the terminal.")
                OptionalToggle("Spinner Tips", isOn: settings.spinnerTipsEnabled)
                    .help("Shows helpful tips in the loading spinner while Claude is thinking.")
                OptionalToggle("Thinking Summaries", isOn: settings.showThinkingSummaries)
                    .help("Displays a summary of Claude's thinking process in the transcript. Toggle with Ctrl+O.")
                OptionalToggle("Prompt Suggestions", isOn: settings.promptSuggestionEnabled)
                    .help("Shows suggested follow-up prompts after Claude finishes responding.")
                OptionalToggle("Reduced Motion", isOn: settings.prefersReducedMotion)
                    .help("Reduces animations for accessibility. Disables the spinner and other motion effects.")
            }

            Section("Session") {
                OptionalStepper(
                    "Cleanup Period",
                    value: settings.cleanupPeriodDays,
                    range: 0...365,
                    unit: "days"
                )
                .help("Number of days to retain session transcripts. Default is 30. Set to 0 to disable persistence entirely.")

                OptionalToggle("Auto Memory", isOn: settings.autoMemoryEnabled)
                    .help("Automatically saves learned context (preferences, patterns) to memory files for future sessions.")
                OptionalToggle("Auto Dream", isOn: settings.autoDreamEnabled)
                    .help("Runs background memory consolidation between sessions to organize and refine stored memories.")
                OptionalToggle("Away Summary", isOn: settings.awaySummaryEnabled)
                    .help("Shows a recap of what happened in the session when you return after being away.")
                OptionalToggle("Respect .gitignore", isOn: settings.respectGitignore)
                    .help("File picker and @ autocomplete will skip files matched by .gitignore patterns.")
                OptionalToggle("Channels", isOn: settings.channelsEnabled)
                    .help("Enables channel notifications from plugins for real-time updates.")
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
