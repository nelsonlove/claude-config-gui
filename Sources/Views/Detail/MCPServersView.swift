import SwiftUI

struct MCPServersView: View {
    @Environment(AppState.self) private var appState
    @State private var editor: MCPConfigEditor?
    @State private var editingServer: MCPServer?
    @State private var newServerName = ""
    @State private var pluginServers: [PluginMCPServer] = []
    @State private var enabledServers: Set<String> = []
    @State private var disabledServers: Set<String> = []
    @State private var enableAllProject: Bool = false
    @State private var testingServer: String?
    @State private var testResult: (server: String, result: MCPConnectionTester.TestResult)?

    private var mcpURL: URL {
        appState.selectedScope.mcpURL(projectRoot: appState.selectedProjectRoot)
    }

    private func approvalStatus(for serverName: String) -> MCPApprovalStatus {
        if enableAllProject { return .enabled }
        if enabledServers.contains(serverName) { return .enabled }
        if disabledServers.contains(serverName) { return .disabled }
        return .pending
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

            if let test = testResult {
                HStack(spacing: 8) {
                    switch test.result {
                    case .success(let name, let version):
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(test.server): connected")
                            .font(.subheadline)
                        Text("— \(name)\(version.map { " v\($0)" } ?? "")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    case .failure(let message):
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("\(test.server): \(message)")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        testResult = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(testResultBackground)
            }

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
                                let status = approvalStatus(for: server.name)
                                MCPServerRow(
                                    server: server,
                                    approvalStatus: status,
                                    isTesting: testingServer == server.name
                                )
                                    .contextMenu {
                                        Button("Edit") { editingServer = server }
                                        Button("Test Connection") {
                                            testConnection(server)
                                        }
                                        .disabled(testingServer != nil)
                                        Divider()
                                        if status != .enabled {
                                            Button("Approve") { setApproval(server.name, enabled: true) }
                                        }
                                        if status != .disabled {
                                            Button("Deny") { setApproval(server.name, enabled: false) }
                                        }
                                        if status != .pending {
                                            Button("Reset to Pending") { clearApproval(server.name) }
                                        }
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
        loadApprovalStatus()
    }

    private func loadApprovalStatus() {
        let settingsURL = ConfigScope.user.settingsURL()
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(ClaudeSettings.self, from: data) else {
            enabledServers = []
            disabledServers = []
            enableAllProject = false
            return
        }
        enabledServers = Set(settings.enabledMcpjsonServers ?? [])
        disabledServers = Set(settings.disabledMcpjsonServers ?? [])
        enableAllProject = settings.enableAllProjectMcpServers ?? false
    }

    private func setApproval(_ serverName: String, enabled: Bool) {
        enabledServers.remove(serverName)
        disabledServers.remove(serverName)
        if enabled {
            enabledServers.insert(serverName)
        } else {
            disabledServers.insert(serverName)
        }
        saveApprovalStatus()
    }

    private func clearApproval(_ serverName: String) {
        enabledServers.remove(serverName)
        disabledServers.remove(serverName)
        saveApprovalStatus()
    }

    private func saveApprovalStatus() {
        let settingsURL = ConfigScope.user.settingsURL()
        // Read-modify-write to preserve other keys
        let fm = FileManager.default
        var dict: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict = existing
        }

        if enabledServers.isEmpty {
            dict.removeValue(forKey: "enabledMcpjsonServers")
        } else {
            dict["enabledMcpjsonServers"] = enabledServers.sorted()
        }

        if disabledServers.isEmpty {
            dict.removeValue(forKey: "disabledMcpjsonServers")
        } else {
            dict["disabledMcpjsonServers"] = disabledServers.sorted()
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) else { return }
        let dir = settingsURL.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: settingsURL, options: .atomic)
    }

    private var testResultBackground: Color {
        guard let test = testResult else { return .clear }
        switch test.result {
        case .success: return .green.opacity(0.08)
        case .failure: return .red.opacity(0.08)
        }
    }

    private func testConnection(_ server: MCPServer) {
        testingServer = server.name
        testResult = nil
        Task {
            let result = await MCPConnectionTester.test(server)
            await MainActor.run {
                testResult = (server: server.name, result: result)
                testingServer = nil
            }
        }
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
    var approvalStatus: MCPApprovalStatus = .pending
    var isTesting: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if isTesting {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 20)
            } else {
                Image(systemName: server.transportType.icon)
                    .foregroundStyle(.tint)
                    .frame(width: 20)
            }

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

            Image(systemName: approvalStatus.icon)
                .foregroundStyle(approvalStatus.color)
                .help(approvalStatus.label.capitalized)

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
