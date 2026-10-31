import AppKit
import Combine
import ServiceManagement

@MainActor
final class LoginStartup: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var message: String?

    init() { refresh() }
    func refresh() {
        enabled = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            message = "Подтвердите автозапуск в Основные → Объекты входа."
        }
    }
    func setEnabled(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            message = nil
        } catch {
            message = "Автозапуск: \(error.localizedDescription)"
        }
        refresh()
    }
}
