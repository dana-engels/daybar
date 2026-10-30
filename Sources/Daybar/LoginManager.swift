import ServiceManagement

@MainActor
protocol LoginManaging {
    var enabled: Bool { get }
    var approvalRequired: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

struct LoginManager: LoginManaging {
    var enabled: Bool { [.enabled, .requiresApproval].contains(SMAppService.mainApp.status) }
    var approvalRequired: Bool { SMAppService.mainApp.status == .requiresApproval }
    func setEnabled(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
    }
}
