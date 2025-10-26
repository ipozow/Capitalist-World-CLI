import Foundation

final class TerminalMode {
    private var configured = false

    @_silgen_name("ConfigureTerminalForPrompt")
    private static func configureTerminal() -> Int32

    @_silgen_name("RestoreTerminalSettings")
    private static func restoreTerminal()

    init() {
        let result = Self.configureTerminal()
        if result == 0 {
            configured = true
        }
    }

    func restoreIfNeeded() {
        guard configured else { return }
        Self.restoreTerminal()
        configured = false
    }

    deinit {
        restoreIfNeeded()
    }
}
