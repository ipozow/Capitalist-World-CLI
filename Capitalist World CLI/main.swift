import Foundation

private enum CLICommand: String {
    case ayuda = "ayuda"
    case salir = "salir"
    case exit = "exit"
}

private func printPrompt() {
    FileHandle.standardOutput.write(Data("capitalist> ".utf8))
}

private func handleCommand(_ input: String) -> Bool {
    guard let command = CLICommand(rawValue: input.lowercased()) else {
        print("Comando pendiente de implementar: \(input)")
        return true
    }

    switch command {
    case .ayuda:
        print("Comandos disponibles: ayuda, salir")
        return true
    case .salir, .exit:
        print("Saliendo...")
        return false
    }
}

print("Capitalist World CLI listo. Escribe 'ayuda' para ver opciones.")

while true {
    printPrompt()
    guard let line = readLine() else {
        print("Entrada finalizada. Saliendo...")
        break
    }

    let command = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if command.isEmpty { continue }
    if handleCommand(command) == false { break }
}
