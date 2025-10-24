# Capitalist World CLI

Capitalist World CLI es un juego de simulación económica pensado para ejecutarse en un cliente de línea de comandos. Persiste el estado con Core Data, ofrece un prompt interactivo y está completamente localizado en español e inglés mediante catálogos `.xcstrings`.

## Características
- Gestión de partidas con Core Data (crear, guardar, abandonar).
- Prompt interactivo con comandos disponibles en español e inglés (`iniciar`/`start`, `guardar`/`save`, etc.).
- Recuperación automática de la última partida activa al iniciar la aplicación.
- Mensajería consistente gracias al catálogo `Localizable.xcstrings` y una capa de localización reutilizable.

## Estructura del código
- `Game.swift`: modelo `NSManagedObject` y descripción dinámica de la entidad.
- `CoreDataStack.swift`: inicializa `NSPersistentContainer` y gestiona el almacenamiento SQLite en `~/Library/Application Support/CapitalistWorldCLI/`.
- `GameManager.swift`: orquesta la partida activa, valida estados de negocio y comunica errores localizados.
- `Localization.swift` + `Localizable.xcstrings`: resuelven cadenas, alias y formatos para ambos idiomas.
- `CLIApplication.swift`: entrada de comandos, loop principal y delegación a `GameManager`.
- `main.swift`: punto de entrada mínimo que inicializa la aplicación CLI.

## Comandos disponibles
- `ayuda` / `help`
- `iniciar <nombre>` / `start <name>` / `begin <name>`
- `guardar` / `save`
- `abandonar` / `abandon`
- `partidas` / `games` / `list`
- `cargar <índice|id>` / `load <index|id>`
- `salir` / `exit` / `quit`

Todos los comandos admiten las variantes sin importar el idioma activo.

## Construcción y ejecución
1. Abre `Capitalist World CLI.xcodeproj` y asegúrate de que los archivos `.swift` y `Localizable.xcstrings` estén incluidos en el target **Capitalist World CLI**.
2. Compila y ejecuta el esquema desde Xcode o usa `swift run` desde la carpeta del proyecto.
3. (Opcional) El catálogo de cadenas permite definir más idiomas desde Xcode > File Inspector.

### Sobrescribir idioma
El runtime detecta el idioma desde `Locale.preferredLanguages`, pero puedes forzarlo con:

```bash
CAPITALIST_LANG=en swift run
CAPITALIST_LANG=es swift run
```

## Contribución
- Mantén cada módulo con una única responsabilidad.
- Documenta cualquier nuevo comando o mensaje en `AGENTS.md` y añade las cadenas correspondientes al catálogo `Localizable.xcstrings`.
- Añade pruebas manuales o automatizadas según corresponda antes de enviar un pull request.
