import Foundation

enum CommandIdentifier: CaseIterable {
    case help
    case start
    case save
    case abandon
    case list
    case load
    case exit

    var key: String {
        switch self {
        case .help:
            return "command.help"
        case .start:
            return "command.start"
        case .save:
            return "command.save"
        case .abandon:
            return "command.abandon"
        case .list:
            return "command.list"
        case .load:
            return "command.load"
        case .exit:
            return "command.exit"
        }
    }
}

final class Localization {
    enum Language: String {
        case spanish = "es"
        case english = "en"

        var localeIdentifier: String {
            switch self {
            case .spanish:
                return "es_CL"
            case .english:
                return "en_US"
            }
        }
    }

    private struct Catalog: Decodable {
        struct Entry: Decodable {
            struct LocalizationUnit: Decodable {
                struct StringUnit: Decodable {
                    let value: String
                }

                let stringUnit: StringUnit
            }

            let localizations: [String: LocalizationUnit]
        }

        let strings: [String: Entry]
    }

    static let shared = Localization()

    let language: Language

    private let locale: Locale
    private let isoFormatter: ISO8601DateFormatter
    private let catalog: [String: [String: String]]

    private init() {
        let resolvedLanguage: Language
        if let override = ProcessInfo.processInfo.environment["CAPITALIST_LANG"]?.lowercased() {
            if override.hasPrefix("en") {
                resolvedLanguage = .english
            } else if override.hasPrefix("es") {
                resolvedLanguage = .spanish
            } else {
                resolvedLanguage = Localization.defaultLanguage()
            }
        } else {
            resolvedLanguage = Localization.defaultLanguage()
        }

        language = resolvedLanguage
        locale = Locale(identifier: resolvedLanguage.localeIdentifier)

        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        catalog = Localization.loadCatalog()
    }

    private static func defaultLanguage() -> Language {
        if let preferred = Locale.preferredLanguages.first?.lowercased(), preferred.hasPrefix("en") {
            return .english
        }
        return .spanish
    }

    private static func loadCatalog() -> [String: [String: String]] {
        guard let url = catalogURL(),
              let data = try? Data(contentsOf: url) else {
            fputs("[Localization] Localizable.xcstrings missing\n", stderr)
            return [:]
        }

        do {
            let decoder = JSONDecoder()
            let catalog = try decoder.decode(Catalog.self, from: data)
            var stringsByLanguage: [String: [String: String]] = [:]

            for (key, entry) in catalog.strings {
                var localizationValues: [String: String] = [:]
                for (code, localization) in entry.localizations {
                    localizationValues[code] = localization.stringUnit.value
                }
                stringsByLanguage[key] = localizationValues
            }

            return stringsByLanguage
        } catch {
            fputs("[Localization] Failed to parse Localizable.xcstrings: \(error)\n", stderr)
            return [:]
        }
    }

    private static func catalogURL() -> URL? {
        if let bundleURL = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings") {
            return bundleURL
        }

        let fileURL = URL(fileURLWithPath: #filePath)
        let directory = fileURL.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("Localizable.xcstrings")
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let alternateCandidate = workingDirectory.appendingPathComponent("Capitalist World CLI/Localizable.xcstrings")
        if FileManager.default.fileExists(atPath: alternateCandidate.path) {
            return alternateCandidate
        }

        return nil
    }

    private func localized(_ key: String) -> String {
        if let value = catalog[key]?[language.rawValue] {
            return value
        }

        if let english = catalog[key]?[Language.english.rawValue] {
            return english
        }

        return key
    }

    private func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, locale: locale, arguments: arguments)
    }

    func primaryCommandName(for identifier: CommandIdentifier) -> String {
        localized("\(identifier.key).primary")
    }

    func aliases(for identifier: CommandIdentifier) -> [String] {
        let raw = localized("\(identifier.key).aliases")
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.isEmpty == false }
    }

    func commandOverviewMessage() -> String {
        let header = localized("command.overview.header")
        let bulletPrefix = localized("command.overview.bulletPrefix")
        let separator = localized("command.alias.separator")

        let items = CommandIdentifier.allCases.map { identifier -> String in
            displayAliases(for: identifier, separator: separator)
        }

        let bullets = items
            .map { "\(bulletPrefix)\($0)" }
            .joined(separator: "\n")

        return "\(header)\n\(bullets)"
    }

    private func displayAliases(for identifier: CommandIdentifier, separator: String) -> String {
        var unique = Set<String>()
        var ordered: [String] = []

        func append(_ value: String) {
            let normalized = value.lowercased()
            if unique.contains(normalized) == false {
                unique.insert(normalized)
                ordered.append(value)
            }
        }

        append(primaryCommandName(for: identifier))
        aliases(for: identifier).forEach(append(_:))

        return ordered.joined(separator: separator)
    }

    func appReadyMessage() -> String {
        formatted("app.ready", primaryCommandName(for: .help))
    }

    func previousGameLoadedMessage(_ summary: String) -> String {
        formatted("previous.loaded", summary)
    }

    func inputEndedMessage() -> String {
        localized("input.ended")
    }

    func unknownCommandMessage(_ command: String) -> String {
        formatted("unknown.command", command)
    }

    func currentGameLine(_ summary: String) -> String {
        formatted("current.game", summary)
    }

    func gameStartedMessage(_ summary: String) -> String {
        formatted("game.started", summary)
    }

    func gameSavedMessage(_ summary: String) -> String {
        formatted("game.saved", summary)
    }

    func gameAbandonedMessage() -> String {
        formatted("game.abandoned", primaryCommandName(for: .start))
    }

    func exitWarningMessage(_ summary: String) -> String {
        formatted("exit.warning", summary)
    }

    func exitingMessage() -> String {
        localized("exiting")
    }

    func gamesHeaderMessage() -> String {
        localized("games.header")
    }

    func gamesEmptyMessage() -> String {
        formatted("games.empty", primaryCommandName(for: .start))
    }

    func gamesEntryMessage(index: Int, statusLabel: String, summary: String) -> String {
        formatted("games.entry", index, statusLabel, summary)
    }

    func statusLabel(for status: GameStatus) -> String {
        switch status {
        case .active:
            return localized("status.label.active")
        case .abandoned:
            return localized("status.label.abandoned")
        }
    }

    func statusLabel(forRawValue raw: String) -> String {
        if let status = GameStatus(rawValue: raw) {
            return statusLabel(for: status)
        }
        return localized("status.label.unknown")
    }

    func loadSuccessMessage(_ summary: String) -> String {
        formatted("load.success", summary)
    }

    func loadMissingArgumentMessage() -> String {
        formatted(
            "load.missingArgument",
            primaryCommandName(for: .load),
            primaryCommandName(for: .list)
        )
    }

    func invalidLoadMessage(_ input: String) -> String {
        formatted(
            "error.invalidSelection",
            input,
            primaryCommandName(for: .list)
        )
    }

    func noGamesAvailableMessage() -> String {
        formatted("error.noGames", primaryCommandName(for: .start))
    }

    func activeGameInProgressMessage(_ name: String) -> String {
        formatted(
            "error.activeGame",
            name,
            primaryCommandName(for: .save),
            primaryCommandName(for: .abandon)
        )
    }

    func noActiveGameMessage() -> String {
        formatted(
            "error.noActiveGame",
            primaryCommandName(for: .start),
            namePlaceholder()
        )
    }

    func persistenceFailureMessage(_ error: Error) -> String {
        formatted("error.persistence", error.localizedDescription)
    }

    func coreDataLoadErrorMessage(_ error: Error) -> String {
        formatted("error.coreData", error.localizedDescription)
    }

    func dataDirectoryErrorMessage(_ error: Error) -> String {
        formatted("error.dataDirectory", error.localizedDescription)
    }

    func statusSummary(name: String, lastSaved: Date) -> String {
        formatted("status.summary", name, isoFormatter.string(from: lastSaved))
    }

    func defaultGameName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let formattedDate = formatter.string(from: date)
        return formatted("default.game.name", formattedDate)
    }

    private func namePlaceholder() -> String {
        localized("placeholder.name")
    }
}
