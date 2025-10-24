import Foundation
import CoreData

enum GameManagerError: LocalizedError {
    case activeGameInProgress(String)
    case noActiveGame
    case noGamesAvailable
    case invalidSelection(String)
    case persistenceFailure(Error)

    var errorDescription: String? {
        let localization = Localization.shared
        switch self {
        case .activeGameInProgress(let name):
            return localization.activeGameInProgressMessage(name)
        case .noActiveGame:
            return localization.noActiveGameMessage()
        case .noGamesAvailable:
            return localization.noGamesAvailableMessage()
        case .invalidSelection(let input):
            return localization.invalidLoadMessage(input)
        case .persistenceFailure(let error):
            return localization.persistenceFailureMessage(error)
        }
    }
}

final class GameManager {
    static let shared = GameManager()

    private let stack = CoreDataStack()
    private let localization = Localization.shared
    private(set) var currentGame: Game?

    private init() {
        currentGame = try? fetchMostRecentActiveGame()
    }

    @discardableResult
    func startGame(named name: String?) throws -> Game {
        if let activeGame = currentGame, activeGame.gameStatus == .active {
            throw GameManagerError.activeGameInProgress(activeGame.name)
        }

        let context = stack.context
        let game = Game(context: context)
        game.id = UUID()
        game.name = name?.isEmpty == false ? name! : localization.defaultGameName(for: Date())
        game.gameStatus = .active
        let now = Date()
        game.createdAt = now
        game.updatedAt = now
        game.lastSavedAt = now

        do {
            try stack.saveIfNeeded()
        } catch {
            throw GameManagerError.persistenceFailure(error)
        }

        currentGame = game
        return game
    }

    @discardableResult
    func saveCurrentGame() throws -> Game {
        guard let game = currentGame, game.gameStatus == .active else {
            throw GameManagerError.noActiveGame
        }

        let now = Date()
        game.lastSavedAt = now
        game.updatedAt = now

        do {
            try stack.saveIfNeeded()
        } catch {
            throw GameManagerError.persistenceFailure(error)
        }

        return game
    }

    func abandonCurrentGame() throws {
        guard let game = currentGame, game.gameStatus == .active else {
            throw GameManagerError.noActiveGame
        }

        game.gameStatus = .abandoned
        game.updatedAt = Date()

        do {
            try stack.saveIfNeeded()
        } catch {
            throw GameManagerError.persistenceFailure(error)
        }

        currentGame = nil
    }

    func fetchAllGames() throws -> [Game] {
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        return try stack.context.fetch(request)
    }

    @discardableResult
    func loadGame(matching input: String) throws -> Game {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw GameManagerError.invalidSelection(input)
        }

        let games = try fetchAllGames()
        guard games.isEmpty == false else {
            throw GameManagerError.noGamesAvailable
        }

        if let index = Int(trimmed), index >= 1, index <= games.count {
            return try activateGame(games[index - 1])
        }

        let lowercased = trimmed.lowercased()
        if let match = games.first(where: { game in
            game.id.uuidString.lowercased().hasPrefix(lowercased) ||
            game.name.lowercased() == lowercased
        }) {
            return try activateGame(match)
        }

        throw GameManagerError.invalidSelection(trimmed)
    }

    func statusSummary(for game: Game) -> String {
        localization.statusSummary(name: game.name, lastSaved: game.lastSavedAt)
    }

    private func activateGame(_ game: Game) throws -> Game {
        let now = Date()
        if currentGame?.objectID != game.objectID {
            currentGame = game
        }

        if game.gameStatus != .active {
            game.gameStatus = .active
        }
        game.updatedAt = now

        do {
            try stack.saveIfNeeded()
        } catch {
            throw GameManagerError.persistenceFailure(error)
        }

        return game
    }

    private func fetchMostRecentActiveGame() throws -> Game? {
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", GameStatus.active.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        request.fetchLimit = 1
        return try stack.context.fetch(request).first
    }
}
