import SwiftUI

@Observable
final class AppState {
    var selectedSection: ConfigSection = .general
    var selectedScope: ConfigScope = .user
    var configEditor: ConfigEditor

    init() {
        self.configEditor = ConfigEditor(scope: .user)
    }

    func switchScope(_ scope: ConfigScope) {
        selectedScope = scope
        configEditor = ConfigEditor(scope: scope)
        configEditor.load()
    }
}
