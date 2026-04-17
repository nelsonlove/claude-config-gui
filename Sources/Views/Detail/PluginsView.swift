import SwiftUI

struct MarketplaceInfo: Identifiable {
    let id: String
    let name: String
    let sourceType: String
    let sourceDetail: String
    let inSettings: Bool  // true = from settings.json, false = from known_marketplaces.json only
}

struct PluginsView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    var body: some View {
        let plugins = editor.settings.enabledPlugins ?? [:]
        let sortedPlugins = plugins.sorted(by: { $0.key < $1.key })

        Form {
            Section {
                if sortedPlugins.isEmpty {
                    Text("No plugins configured in this scope")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPlugins, id: \.key) { key, enabled in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { enabled },
                                set: { newValue in
                                    editor.mutate { settings in
                                        var plugins = settings.enabledPlugins ?? [:]
                                        plugins[key] = newValue
                                        settings.enabledPlugins = plugins
                                    }
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
                                editor.mutate { settings in
                                    var plugins = settings.enabledPlugins ?? [:]
                                    plugins.removeValue(forKey: key)
                                    settings.enabledPlugins = plugins.isEmpty ? nil : plugins
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } header: {
                Text("Enabled Plugins (\(plugins.count))")
            } footer: {
                Text("Plugins add skills, agents, hooks, and MCP servers. Format: plugin-name@marketplace-id.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                let allMarketplaces = loadAllMarketplaces()
                if allMarketplaces.isEmpty {
                    Text("No marketplaces found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allMarketplaces) { mp in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(mp.name)
                                    .font(.headline)
                                if !mp.inSettings {
                                    Text("auto")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(.tint.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                            }
                            HStack {
                                Text(mp.sourceType)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                if !mp.sourceDetail.isEmpty {
                                    Text(mp.sourceDetail)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Marketplaces")
            } footer: {
                Text("Plugin registries. \"auto\" marketplaces come from known_marketplaces.json.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// Merges marketplaces from settings.json and known_marketplaces.json.
    private func loadAllMarketplaces() -> [MarketplaceInfo] {
        var results: [String: MarketplaceInfo] = [:]

        // From settings.json
        for (name, config) in editor.settings.extraKnownMarketplaces ?? [:] {
            let src = config.source
            results[name] = MarketplaceInfo(
                id: name,
                name: name,
                sourceType: src?.source ?? "unknown",
                sourceDetail: src?.repo ?? src?.url ?? src?.package ?? "",
                inSettings: true
            )
        }

        // From known_marketplaces.json
        let home = FileManager.default.homeDirectoryForCurrentUser
        let kmPath = home.appendingPathComponent(".claude/plugins/known_marketplaces.json")
        if let data = try? Data(contentsOf: kmPath),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for name in dict.keys where results[name] == nil {
                // Parse source info from the known marketplace entry
                var sourceType = "unknown"
                var sourceDetail = ""
                if let entry = dict[name] as? [String: Any],
                   let source = entry["source"] as? [String: Any] {
                    sourceType = source["source"] as? String ?? "unknown"
                    sourceDetail = source["repo"] as? String
                        ?? source["url"] as? String
                        ?? source["package"] as? String
                        ?? ""
                }
                results[name] = MarketplaceInfo(
                    id: name,
                    name: name,
                    sourceType: sourceType,
                    sourceDetail: sourceDetail,
                    inSettings: false
                )
            }
        }

        return results.values.sorted { $0.name < $1.name }
    }
}
