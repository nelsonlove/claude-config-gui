import SwiftUI

struct PluginsView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    var body: some View {
        let plugins = editor.settings.enabledPlugins ?? [:]
        let sortedPlugins = plugins.sorted(by: { $0.key < $1.key })

        Form {
            Section("Enabled Plugins (\(plugins.count))") {
                if sortedPlugins.isEmpty {
                    Text("No plugins configured in this scope")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPlugins, id: \.key) { key, enabled in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { enabled },
                                set: { newValue in
                                    var plugins = editor.settings.enabledPlugins ?? [:]
                                    plugins[key] = newValue
                                    editor.settings.enabledPlugins = plugins
                                    editor.markDirty()
                                }
                            )) {
                                VStack(alignment: .leading) {
                                    let parts = key.split(separator: "@", maxSplits: 1)
                                    Text(String(parts.first ?? Substring(key)))
                                        .font(.body)
                                    if parts.count > 1 {
                                        Text("@\(parts[1])")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            Button(role: .destructive) {
                                var plugins = editor.settings.enabledPlugins ?? [:]
                                plugins.removeValue(forKey: key)
                                editor.settings.enabledPlugins = plugins.isEmpty ? nil : plugins
                                editor.markDirty()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section("Marketplaces") {
                let marketplaces = editor.settings.extraKnownMarketplaces ?? [:]
                if marketplaces.isEmpty {
                    Text("No extra marketplaces configured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(marketplaces.sorted(by: { $0.key < $1.key }), id: \.key) { key, config in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(key)
                                .font(.headline)
                            if let source = config.source {
                                HStack {
                                    Text(source.source ?? "unknown")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    if let repo = source.repo {
                                        Text(repo)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
