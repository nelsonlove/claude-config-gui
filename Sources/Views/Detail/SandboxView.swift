import SwiftUI

struct SandboxView: View {
    @Environment(AppState.self) private var appState

    private var editor: ConfigEditor { appState.configEditor }

    var body: some View {
        let sandbox = Binding(
            get: { self.editor.settings.sandbox ?? SandboxConfig() },
            set: { self.editor.settings.sandbox = $0; self.editor.markDirty() }
        )

        Form {
            Section("General") {
                OptionalToggle("Sandbox Enabled", isOn: sandbox.enabled)
                    .described("Restricts Claude's filesystem and network access.")
                OptionalToggle("Fail if Unavailable", isOn: sandbox.failIfUnavailable)
                    .described("Fail instead of running unsandboxed when sandbox runtime is missing.")
                OptionalToggle("Auto-allow Bash if Sandboxed", isOn: sandbox.autoAllowBashIfSandboxed)
                    .described("Auto-approve all Bash commands when sandboxed, since they're contained.")
                OptionalToggle("Allow Unsandboxed Commands", isOn: sandbox.allowUnsandboxedCommands)
                    .described("Let certain commands (e.g. docker) run outside the sandbox.")
            }

            Section("Filesystem") {
                let fs = Binding(
                    get: { sandbox.wrappedValue.filesystem ?? SandboxFilesystem() },
                    set: { sandbox.wrappedValue.filesystem = $0 }
                )

                StringListEditor(title: "Allow Write", help: "Paths where sandboxed processes can write files.", items: Binding(
                    get: { fs.wrappedValue.allowWrite ?? [] },
                    set: { fs.wrappedValue.allowWrite = $0.isEmpty ? nil : $0 }
                ), placeholder: "/tmp/build")

                StringListEditor(title: "Deny Write", help: "Paths blocked from writing, even inside the sandbox.", items: Binding(
                    get: { fs.wrappedValue.denyWrite ?? [] },
                    set: { fs.wrappedValue.denyWrite = $0.isEmpty ? nil : $0 }
                ), placeholder: "/etc")

                StringListEditor(title: "Deny Read", help: "Paths blocked from reading (e.g. secrets, credentials).", items: Binding(
                    get: { fs.wrappedValue.denyRead ?? [] },
                    set: { fs.wrappedValue.denyRead = $0.isEmpty ? nil : $0 }
                ), placeholder: "~/.aws/credentials")

                StringListEditor(title: "Allow Read", help: "Extra paths readable inside the sandbox.", items: Binding(
                    get: { fs.wrappedValue.allowRead ?? [] },
                    set: { fs.wrappedValue.allowRead = $0.isEmpty ? nil : $0 }
                ), placeholder: ".")
            }

            Section("Network") {
                let net = Binding(
                    get: { sandbox.wrappedValue.network ?? SandboxNetwork() },
                    set: { sandbox.wrappedValue.network = $0 }
                )

                StringListEditor(title: "Allowed Domains", help: "Domains reachable from inside the sandbox.", items: Binding(
                    get: { net.wrappedValue.allowedDomains ?? [] },
                    set: { net.wrappedValue.allowedDomains = $0.isEmpty ? nil : $0 }
                ), placeholder: "github.com")

                OptionalToggle("Allow All Unix Sockets", isOn: net.allowAllUnixSockets)
                    .described("Permits connections to any Unix socket (Docker, databases).")
                OptionalToggle("Allow Local Binding", isOn: net.allowLocalBinding)
                    .described("Allows binding to localhost ports (needed for dev servers).")
            }

            Section("Excluded Commands") {
                StringListEditor(title: "Excluded from Sandbox", help: "Commands that bypass sandboxing entirely.", items: Binding(
                    get: { sandbox.wrappedValue.excludedCommands ?? [] },
                    set: { sandbox.wrappedValue.excludedCommands = $0.isEmpty ? nil : $0 }
                ), placeholder: "docker *")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
