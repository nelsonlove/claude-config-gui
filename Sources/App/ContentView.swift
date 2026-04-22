import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView(selection: $appState.selectedSection)
        } detail: {
            DetailView(section: appState.selectedSection)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appState.configEditor.load()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .help("Reload from disk")

                Button {
                    appState.configEditor.save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .help("Save now")
                .disabled(!appState.configEditor.isDirty)

                Divider()

                if appState.selectedSection.group == .settings {
                    Picker("View", selection: $appState.settingsViewMode) {
                        ForEach(SettingsViewMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .help("Form: editable panels · JSON: raw editor · Effective: merged read-only view")
                    .onChange(of: appState.settingsViewMode) { oldMode, newMode in
                        if newMode == .rawJSON {
                            appState.configEditor.syncRawFromSettings()
                        } else if oldMode == .rawJSON {
                            // Leaving raw JSON — apply any edits
                            _ = appState.configEditor.syncSettingsFromRaw()
                        }
                    }
                }
            }
        }
        .navigationTitle(windowTitle)
        .onAppear {
            appState.configEditor.load()
        }
        .keyboardShortcut(for: .save) {
            appState.configEditor.save()
        }
        .keyboardShortcut(for: .undo) {
            appState.configEditor.undoManager.undo()
        }
        .keyboardShortcut(for: .redo) {
            appState.configEditor.undoManager.redo()
        }
    }

    private var windowTitle: String {
        let scope = appState.selectedScope
        switch scope {
        case .user:
            return "Claude Config — User"
        case .project, .local:
            let label = scope == .project ? "Project" : "Local"
            if let root = appState.selectedProjectRoot {
                let name = root.lastPathComponent
                return "Claude Config — \(label): \(name)"
            }
            return "Claude Config — \(label)"
        }
    }
}

// MARK: - Cmd+S keyboard shortcut

extension View {
    func keyboardShortcut(for action: KeyAction, perform: @escaping () -> Void) -> some View {
        self.background(
            Button("") { perform() }
                .keyboardShortcut(action.key, modifiers: action.modifiers)
                .hidden()
        )
    }
}

enum KeyAction {
    case save, undo, redo

    var key: KeyEquivalent {
        switch self {
        case .save: "s"
        case .undo: "z"
        case .redo: "z"
        }
    }

    var modifiers: EventModifiers {
        switch self {
        case .save: .command
        case .undo: .command
        case .redo: [.command, .shift]
        }
    }
}
