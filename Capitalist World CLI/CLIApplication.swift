import Foundation

@_silgen_name("RenderPrompt")
private func RenderPrompt(_ prompt: UnsafePointer<CChar>, _ statusLine: UnsafePointer<CChar>)
@_silgen_name("UpdateStatusLine")
private func UpdateStatusLine(_ statusLine: UnsafePointer<CChar>)

final class CLIApplication {
    private struct PromptSnapshot {
        var promptText: String = "capitalist> "
        var balanceLabel: String
        var balanceValue: String
        var profitsLabel: String
        var profitsValue: String
        var dateLabel: String
        var speedLabel: String
    }

    private let localization = Localization.shared
    private let gameManager: GameManager
    private let promptRenderQueue = DispatchQueue(label: "com.capitalistworld.promptRender")
    private let simulationClock: SimulationClock
    private let terminalMode = TerminalMode()

    private var promptSnapshot: PromptSnapshot
    private var hasRenderedPrompt = false
    private var lastStatusLine: String?

    init(gameManager: GameManager) {
        self.gameManager = gameManager

        let defaultBalance = 10_000_000.0
        promptSnapshot = PromptSnapshot(
            balanceLabel: localization.promptBalanceLabel(),
            balanceValue: localization.formattedBalance(gameManager.currentGame?.balance ?? defaultBalance),
            profitsLabel: localization.promptProfitsLabel(),
            profitsValue: localization.formattedBalance(0),
            dateLabel: localization.promptDateLabel(),
            speedLabel: localization.promptSpeedLabel()
        )

        simulationClock = SimulationClock(
            referenceDate: localization.promptReferenceDate(),
            callbackQueue: promptRenderQueue
        )

        simulationClock.delegate = self
    }

    func run() {
        defer { terminalMode.restoreIfNeeded() }

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

        if trimmed.hasPrefix(":") {
            let shortcutArgument = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            return handleSpeedShortcut(argument: shortcutArgument)
        }

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
            if let active = gameManager.currentGame, active.gameStatus == .active {
                print(localization.activeGameInProgressMessage(active.name))
                return true
            }

            let playerName = readRequiredInput(prompt: localization.playerNamePrompt())
            let companyName = readRequiredInput(prompt: localization.companyNamePrompt())

            do {
                let game = try gameManager.startGame(named: arguments, playerName: playerName, companyName: companyName)
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
        case .speed:
            guard let arguments, arguments.isEmpty == false else {
                let example = localization.speedValueString(for: SimulationClock.Speed.x2.rawValue)
                print(localization.speedMissingArgumentMessage(example))
                return true
            }

            guard let newSpeed = SimulationClock.Speed.from(argument: arguments) else {
                let valid = localization.speedValidOptionsList()
                print(localization.speedInvalidValueMessage(arguments, validOptions: valid))
                return true
            }

            setSimulationSpeed(newSpeed)
            let speedValue = localization.speedValueString(for: newSpeed.rawValue)
            print(localization.speedUpdatedMessage(speedValue))
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

    private func readRequiredInput(prompt: String) -> String {
        while true {
            print(prompt)
            if let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), line.isEmpty == false {
                return line
            }
            print(localization.emptyInputWarning())
        }
    }

    private func setSimulationSpeed(_ speed: SimulationClock.Speed) {
        simulationClock.setSpeed(speed)
    }

    private func handleSpeedShortcut(argument: String) -> Bool {
        guard argument.isEmpty == false else {
            let example = ":" + localization.speedValueString(for: SimulationClock.Speed.x2.rawValue)
            print(localization.speedMissingArgumentMessage(example))
            return true
        }

        guard let newSpeed = SimulationClock.Speed.from(argument: argument) else {
            let valid = localization.speedValidOptionsList()
            print(localization.speedInvalidValueMessage(argument, validOptions: valid))
            return true
        }

        setSimulationSpeed(newSpeed)
        let speedValue = localization.speedValueString(for: newSpeed.rawValue)
        print(localization.speedUpdatedMessage(speedValue))
        return true
    }

    private func printPrompt() {
        let promptText = "capitalist> "
        let defaultBalance = 10_000_000.0
        let balanceValue = gameManager.currentGame?.balance ?? defaultBalance
        let balanceText = localization.formattedBalance(balanceValue)
        let profitsText = localization.formattedBalance(0)

        let balanceLabel = localization.promptBalanceLabel()
        let profitsLabel = localization.promptProfitsLabel()
        let dateLabel = localization.promptDateLabel()
        let speedLabel = localization.promptSpeedLabel()

        promptRenderQueue.sync {
            promptSnapshot.promptText = promptText
            promptSnapshot.balanceLabel = balanceLabel
            promptSnapshot.balanceValue = balanceText
            promptSnapshot.profitsLabel = profitsLabel
            promptSnapshot.profitsValue = profitsText
            promptSnapshot.dateLabel = dateLabel
            promptSnapshot.speedLabel = speedLabel
            lastStatusLine = nil
            hasRenderedPrompt = false
        }

        let currentDate = simulationClock.currentDate()
        renderPrompt(for: currentDate, forceFull: true, synchronous: true)
    }

    private func renderPrompt(for date: Date, forceFull: Bool = false, synchronous: Bool = false) {
        let work = { [weak self] in
            guard let self else { return }

            let dateText = self.localization.promptFormattedDate(from: date)
            let speedValue = self.localization.speedValueString(for: self.simulationClock.currentSpeedRawValue())
            let separator = String(repeating: " ", count: 4)

            let columns = [
                (self.promptSnapshot.balanceLabel, self.promptSnapshot.balanceValue),
                (self.promptSnapshot.profitsLabel, self.promptSnapshot.profitsValue),
                (self.promptSnapshot.dateLabel, dateText),
                (self.promptSnapshot.speedLabel, speedValue)
            ]

            let statusLine = columns
                .map { "\($0.0): \($0.1)" }
                .joined(separator: separator)

            if !forceFull, let last = self.lastStatusLine, last == statusLine {
                return
            }

            if forceFull || self.hasRenderedPrompt == false {
                self.promptSnapshot.promptText.withCString { promptPtr in
                    statusLine.withCString { statusPtr in
                        RenderPrompt(promptPtr, statusPtr)
                    }
                }
                self.hasRenderedPrompt = true
            } else {
                statusLine.withCString { statusPtr in
                    UpdateStatusLine(statusPtr)
                }
            }

            self.lastStatusLine = statusLine
        }

        if synchronous {
            promptRenderQueue.sync(execute: work)
        } else {
            promptRenderQueue.async(execute: work)
        }
    }
}

extension CLIApplication: SimulationClockDelegate {
    func simulationClock(_ clock: SimulationClock, didAdvanceTo date: Date) {
        renderPrompt(for: date)
    }
}
