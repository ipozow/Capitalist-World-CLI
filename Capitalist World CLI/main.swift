import Foundation

TerminalLauncher.ensureInteractiveSession()

let application = CLIApplication(gameManager: GameManager.shared)
application.run()
