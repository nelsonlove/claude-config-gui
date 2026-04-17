import SwiftUI

struct RawJSONView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            if let error = editor.rawJSONError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    Spacer()
                    Button("Revert") {
                        editor.syncRawFromSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.red.opacity(0.08))
            }

            TextEditor(text: Binding(
                get: { editor.rawJSON },
                set: { editor.rawJSON = $0 }
            ))
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.visible)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            editor.syncRawFromSettings()
        }
    }
}
