import Foundation

enum CommandIdentifier: CaseIterable {
    case help
    case start
    case save
    case abandon
    case list
    case load
    case speed
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
        case .speed:
            return "command.speed"
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
    private let currencyFormatter: NumberFormatter
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

        currencyFormatter = NumberFormatter()
        currencyFormatter.locale = locale
        currencyFormatter.numberStyle = .currency
        currencyFormatter.maximumFractionDigits = 0
        currencyFormatter.minimumFractionDigits = 0

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

    func statusSummary(name: String, playerName: String, companyName: String, balance: Double, lastSaved: Date) -> String {
        formatted(
            "status.summary",
            sanitizedGameName(name),
            sanitizedPlayerName(playerName),
            sanitizedCompanyName(companyName),
            formatBalance(balance),
            isoFormatter.string(from: lastSaved)
        )
    }

    func defaultGameName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let formattedDate = formatter.string(from: date)
        return formatted("default.game.name", formattedDate)
    }

    func playerNamePrompt() -> String {
        localized("start.prompt.playerName")
    }

    func companyNamePrompt() -> String {
        localized("start.prompt.companyName")
    }

    func emptyInputWarning() -> String {
        localized("start.error.emptyInput")
    }

    func formattedBalance(_ amount: Double) -> String {
        formatBalance(amount)
    }

    func promptBalanceLabel() -> String {
        localized("prompt.balance")
    }

    func promptProfitsLabel() -> String {
        localized("prompt.profits")
    }

    func promptDateLabel() -> String {
        localized("prompt.date")
    }

    func promptSpeedLabel() -> String {
        localized("prompt.speed")
    }

    func promptReferenceDate() -> Date {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 1900
        components.month = 1
        components.day = 1
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    func promptFormattedDate(from date: Date) -> String {
        formatPromptDate(date)
    }

    func promptReferenceDateString() -> String {
        promptFormattedDate(from: promptReferenceDate())
    }

    func speedValueString(for rawValue: Int) -> String {
        formatted("speed.value.format", rawValue)
    }

    func speedMissingArgumentMessage(_ example: String) -> String {
        formatted("speed.missingArgument", example)
    }

    func speedInvalidValueMessage(_ input: String, validOptions: String) -> String {
        formatted("speed.invalidValue", input, validOptions)
    }

    func speedUpdatedMessage(_ speedValue: String) -> String {
        formatted("speed.updated", speedValue)
    }

    func speedValidOptionsList() -> String {
        localized("speed.validOptions")
    }

    private func sanitizedGameName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? localized("status.label.unknownGame") : trimmed
    }

    private func sanitizedPlayerName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? localized("status.label.unknownPlayer") : trimmed
    }

    private func sanitizedCompanyName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? localized("status.label.unknownCompany") : trimmed
    }

    private func namePlaceholder() -> String {
        localized("placeholder.name")
    }

    private func formatBalance(_ amount: Double) -> String {
        if let formatted = currencyFormatter.string(from: NSNumber(value: amount)) {
            return formatted
        }
        return String(format: "%.0f", amount)
    }

    private func formatPromptDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        switch language {
        case .spanish:
            formatter.dateFormat = "dd-MM-yyyy"
        case .english:
            formatter.dateFormat = "MM-dd-yyyy"
        }

        return formatter.string(from: date)
    }
}
