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
                    .help("Restricts Claude's filesystem and network access to prevent unintended side effects.")
                OptionalToggle("Fail if Unavailable", isOn: sandbox.failIfUnavailable)
                    .help("If the sandbox runtime isn't available, fail rather than running unsandboxed.")
                OptionalToggle("Auto-allow Bash if Sandboxed", isOn: sandbox.autoAllowBashIfSandboxed)
                    .help("Automatically approve all Bash commands when the sandbox is active, since they're contained.")
                OptionalToggle("Allow Unsandboxed Commands", isOn: sandbox.allowUnsandboxedCommands)
                    .help("Permits certain commands to run outside the sandbox (e.g. docker, system tools).")
            }

            Section("Filesystem") {
                let fs = Binding(
                    get: { sandbox.wrappedValue.filesystem ?? SandboxFilesystem() },
                    set: { sandbox.wrappedValue.filesystem = $0 }
                )

                StringListEditor(title: "Allow Write", items: Binding(
                    get: { fs.wrappedValue.allowWrite ?? [] },
                    set: { fs.wrappedValue.allowWrite = $0.isEmpty ? nil : $0 }
                ), placeholder: "/tmp/build")

                StringListEditor(title: "Deny Write", items: Binding(
                    get: { fs.wrappedValue.denyWrite ?? [] },
                    set: { fs.wrappedValue.denyWrite = $0.isEmpty ? nil : $0 }
                ), placeholder: "/etc")

                StringListEditor(title: "Deny Read", items: Binding(
                    get: { fs.wrappedValue.denyRead ?? [] },
                    set: { fs.wrappedValue.denyRead = $0.isEmpty ? nil : $0 }
                ), placeholder: "~/.aws/credentials")

                StringListEditor(title: "Allow Read", items: Binding(
                    get: { fs.wrappedValue.allowRead ?? [] },
                    set: { fs.wrappedValue.allowRead = $0.isEmpty ? nil : $0 }
                ), placeholder: ".")
            }

            Section("Network") {
                let net = Binding(
                    get: { sandbox.wrappedValue.network ?? SandboxNetwork() },
                    set: { sandbox.wrappedValue.network = $0 }
                )

                StringListEditor(title: "Allowed Domains", items: Binding(
                    get: { net.wrappedValue.allowedDomains ?? [] },
                    set: { net.wrappedValue.allowedDomains = $0.isEmpty ? nil : $0 }
                ), placeholder: "github.com")

                OptionalToggle("Allow All Unix Sockets", isOn: net.allowAllUnixSockets)
                    .help("Permits connections to any Unix domain socket (e.g. Docker, database sockets).")
                OptionalToggle("Allow Local Binding", isOn: net.allowLocalBinding)
                    .help("Allows processes to bind to localhost ports (needed for dev servers).")
            }

            Section("Excluded Commands") {
                StringListEditor(title: "Excluded from Sandbox", items: Binding(
                    get: { sandbox.wrappedValue.excludedCommands ?? [] },
                    set: { sandbox.wrappedValue.excludedCommands = $0.isEmpty ? nil : $0 }
                ), placeholder: "docker *")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
