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

                Toggle(isOn: $appState.showRawJSON) {
                    Label("JSON", systemImage: "curlybraces")
                }
                .toggleStyle(.button)
                .help("Toggle raw JSON editor")
                .onChange(of: appState.showRawJSON) { _, showRaw in
                    if showRaw {
                        appState.configEditor.syncRawFromSettings()
                    } else {
                        // Switching back to form — apply any raw edits
                        _ = appState.configEditor.syncSettingsFromRaw()
                    }
                }
            }
        }
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
