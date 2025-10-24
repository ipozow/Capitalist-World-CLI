import Foundation

final class CLIApplication {
    private let localization = Localization.shared
    private let gameManager: GameManager

    init(gameManager: GameManager) {
        self.gameManager = gameManager
    }

    func run() {
        print(localization.appReadyMessage())

        if let game = gameManager.currentGame {
            print(localization.previousGameLoadedMessage(gameManager.statusSummary(for: game)))
        }

        while true {
            printPrompt()
            guard let line = readLine() else {
                print(localization.inputEndedMessage())
                break
            }

            if handleCommand(line) == false { break }
        }
    }

    private func handleCommand(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return true }

        let components = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let keyword = components.first else { return true }

        let arguments = components.count > 1 ? String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines) : nil
        guard let identifier = commandIdentifier(for: String(keyword).lowercased()) else {
            print(localization.unknownCommandMessage(trimmed))
            return true
        }

        switch identifier {
        case .help:
            print(localization.commandOverviewMessage())
            if let game = gameManager.currentGame {
                print(localization.currentGameLine(gameManager.statusSummary(for: game)))
            }
            return true
        case .start:
            do {
                let game = try gameManager.startGame(named: arguments)
                print(localization.gameStartedMessage(gameManager.statusSummary(for: game)))
            } catch {
                print(error.localizedDescription)
            }
            return true
        case .save:
            do {
                let game = try gameManager.saveCurrentGame()
                print(localization.gameSavedMessage(gameManager.statusSummary(for: game)))
            } catch {
                print(error.localizedDescription)
            }
            return true
        case .abandon:
            do {
                try gameManager.abandonCurrentGame()
                print(localization.gameAbandonedMessage())
            } catch {
                print(error.localizedDescription)
            }
            return true
        case .list:
            do {
                let games = try gameManager.fetchAllGames()
                guard games.isEmpty == false else {
                    print(localization.gamesEmptyMessage())
                    return true
                }

                print(localization.gamesHeaderMessage())
                for (index, game) in games.enumerated() {
                    let statusLabel = localization.statusLabel(forRawValue: game.status)
                    let summary = gameManager.statusSummary(for: game)
                    print(localization.gamesEntryMessage(index: index + 1, statusLabel: statusLabel, summary: summary))
                }
            } catch {
                print(error.localizedDescription)
            }
            return true
        case .load:
            guard let arguments, arguments.isEmpty == false else {
                print(localization.loadMissingArgumentMessage())
                return true
            }

            do {
                let game = try gameManager.loadGame(matching: arguments)
                print(localization.loadSuccessMessage(gameManager.statusSummary(for: game)))
            } catch {
                print(error.localizedDescription)
            }
            return true
        case .exit:
            if let game = gameManager.currentGame {
                print(localization.exitWarningMessage(gameManager.statusSummary(for: game)))
            }
            print(localization.exitingMessage())
            return false
        }
    }

    private func commandIdentifier(for keyword: String) -> CommandIdentifier? {
        for identifier in CommandIdentifier.allCases {
            let aliases = localization.aliases(for: identifier)
            if aliases.contains(keyword) {
                return identifier
            }
        }
        return nil
    }

    private func printPrompt() {
        FileHandle.standardOutput.write(Data("capitalist> ".utf8))
    }
}
