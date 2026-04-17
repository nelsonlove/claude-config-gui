import SwiftUI

struct MCPServersView: View {
    @Environment(AppState.self) private var appState
    @State private var editor: MCPConfigEditor?
    @State private var editingServer: MCPServer?
    @State private var newServerName = ""
    @State private var pluginServers: [PluginMCPServer] = []

    private var mcpURL: URL {
        appState.selectedScope.mcpURL(projectRoot: appState.selectedProjectRoot)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("MCP Servers")
                    .font(.headline)
                Spacer()
                Text(appState.selectedScope.mcpDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if editor?.isDirty == true {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if let error = editor?.loadError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.red.opacity(0.08))
            }

            if let editing = editingServer {
                MCPServerEditorView(server: editing) { saved in
                    editor?.updateServer(saved)
                    editingServer = nil
                } onCancel: {
                    editingServer = nil
                }
            } else {
                Form {
                    Section {
                        let servers = editor?.servers ?? []
                        if servers.isEmpty {
                            ContentUnavailableView(
                                "No MCP Servers",
                                systemImage: "server.rack",
                                description: Text("Add a server to connect Claude to external tools.")
                            )
                        } else {
                            ForEach(Array(servers.enumerated()), id: \.element.name) { index, server in
                                MCPServerRow(server: server)
                                    .contextMenu {
                                        Button("Edit") { editingServer = server }
                                        Divider()
                                        Button("Delete", role: .destructive) {
                                            editor?.removeServer(at: index)
                                        }
                                    }
                                    .onTapGesture(count: 2) {
                                        editingServer = server
                                    }
                            }
                        }
                    } header: {
                        Text("Servers (\(editor?.servers.count ?? 0))")
                    } footer: {
                        Text("MCP servers provide Claude with tools for databases, APIs, browsers, and other external services. Double-click to edit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Section("Add Server") {
                        HStack {
                            TextField("Server name", text: $newServerName, prompt: Text("e.g. my-database"))
                                .font(.system(.body, design: .monospaced))
                                .onSubmit { addServer() }
                            Button("Add") { addServer() }
                                .disabled(newServerName.isEmpty)
                        }
                    }

                    if !pluginServers.isEmpty {
                        Section {
                            ForEach(pluginServers) { ps in
                                HStack(spacing: 10) {
                                    Image(systemName: "puzzlepiece.extension")
                                        .foregroundStyle(.tint)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ps.serverName)
                                            .font(.system(.body, design: .monospaced))
                                        Text(ps.pluginName)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("plugin")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            Text("Plugin Servers (\(pluginServers.count))")
                        } footer: {
                            Text("These servers are provided by installed plugins and managed automatically.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadForCurrentScope() }
        .onChange(of: appState.selectedScope) { _, _ in loadForCurrentScope() }
        .onChange(of: appState.selectedProjectRoot) { _, _ in loadForCurrentScope() }
    }

    private func loadForCurrentScope() {
        editor?.save()
        let newEditor = MCPConfigEditor(url: mcpURL)
        newEditor.load()
        editor = newEditor
        pluginServers = PluginMCPServer.scanAll()
    }

    private func addServer() {
        let name = newServerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        editor?.addServer(name: name)
        newServerName = ""
        editingServer = editor?.servers.first { $0.name == name }
    }
}

// MARK: - Server row

struct MCPServerRow: View {
    let server: MCPServer

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: server.transportType.icon)
                .foregroundStyle(.tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.system(.body, design: .monospaced))
                Text(server.displaySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(server.transportType.label)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Server editor

struct MCPServerEditorView: View {
    @State var server: MCPServer
    let onSave: (MCPServer) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text(server.name)
                    .font(.headline)
                Spacer()
                Button("Save") { onSave(server) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            Form {
                Section("Transport") {
                    Picker("Type", selection: $server.transportType) {
                        ForEach(TransportType.allCases) { t in
                            Label(t.label, systemImage: t.icon).tag(t)
                        }
                    }
                    .described("stdio: local command. SSE/HTTP/WS: remote server URL.")
                }

                switch server.transportType {
                case .stdio:
                    Section("Command") {
                        TextField("Command", text: Binding(
                            get: { server.command ?? "" },
                            set: { server.command = $0.isEmpty ? nil : $0 }
                        ), prompt: Text("e.g. npx, uvx, node"))
                        .font(.system(.body, design: .monospaced))
                        .described("The executable to run.")

                        ArgsEditor(args: Binding(
                            get: { server.args ?? [] },
                            set: { server.args = $0.isEmpty ? nil : $0 }
                        ))
                    }

                case .sse, .http, .ws:
                    Section("Connection") {
                        TextField("URL", text: Binding(
                            get: { server.url ?? "" },
                            set: { server.url = $0.isEmpty ? nil : $0 }
                        ), prompt: Text("https://localhost:3000/mcp"))
                        .font(.system(.body, design: .monospaced))
                        .described("Server endpoint URL.")
                    }
                }

                Section("Environment Variables") {
                    let env = Binding(
                        get: { server.env ?? [:] },
                        set: { server.env = $0.isEmpty ? nil : $0 }
                    )

                    ForEach(env.wrappedValue.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text(key).font(.system(.body, design: .monospaced))
                            Text("=").foregroundStyle(.secondary)
                            Text(value).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
                            Spacer()
                            Button(role: .destructive) {
                                var e = env.wrappedValue
                                e.removeValue(forKey: key)
                                env.wrappedValue = e
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    EnvVarAdder(env: env)
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Args editor

struct ArgsEditor: View {
    @Binding var args: [String]
    @State private var newArg = ""

    var body: some View {
        ForEach(Array(args.enumerated()), id: \.offset) { index, arg in
            HStack {
                Text(arg)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Button(role: .destructive) {
                    args.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }

        HStack {
            TextField("Argument", text: $newArg, prompt: Text("e.g. --port 3000"))
                .font(.system(.body, design: .monospaced))
                .onSubmit { addArg() }
            Button("Add") { addArg() }
                .disabled(newArg.isEmpty)
        }
    }

    private func addArg() {
        let trimmed = newArg.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        args.append(trimmed)
        newArg = ""
    }
}
