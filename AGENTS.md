# AGENTS

## Objetivo
Este agente expone un CLI para gestionar partidas de "Capitalist World". La interfaz corre en terminal y persiste el estado con Core Data, evitando una "god view" centralizada.

## Componentes
- `Game` + `GameStatus`: describen el modelo de partida y su estado de negocio.
- `CoreDataStack`: encapsula la configuración y acceso al `NSPersistentContainer`.
- `GameManager`: orquesta la vida de una partida activa y valida la persistencia.
- `Localization`: centraliza los textos y alias de comandos apoyándose en `Localizable.xcstrings`.
- `Localizable.xcstrings`: catálogo de cadenas generado por Xcode con variantes en español e inglés.
- `CLIApplication`: procesa comandos del usuario y delega la lógica al `GameManager`.
- `main.swift`: punto de entrada mínimo que simplemente inicia la aplicación CLI.

## Flujo de ejecución
1. `main.swift` crea `CLIApplication` con el `GameManager` compartido y ejecuta `run()`.
2. `CLIApplication` muestra un prompt continuo y traduce comandos en llamadas a `GameManager`.
3. `GameManager` crea, guarda o abandona partidas utilizando `CoreDataStack`.
4. `CoreDataStack` garantiza que el modelo `Game` se almacene en SQLite dentro de `~/Library/Application Support/CapitalistWorldCLI/`.

## Comandos soportados
- `ayuda` / `help`: muestra los comandos disponibles y la partida actual, si existe.
- `iniciar` / `start` `<nombre>` / `<name>`: comienza una partida nueva (se genera un nombre por defecto si se omite).
- `guardar` / `save`: persiste la partida activa y actualiza el sello temporal.
- `abandonar` / `abandon`: marca la partida activa como abandonada.
- `partidas` / `games` / `list`: lista las partidas almacenadas con su estado y la marca temporal.
- `cargar <índice|id>` / `load <index|id>`: asigna la partida elegida como actual.
- `salir` / `exit` / `quit`: finaliza la sesión (advierte si hay una partida sin guardar recientemente).

## Guía para agentes
- Mantén cada módulo enfocado en una responsabilidad. No mezcles lógica de interfaz con persistencia.
- Prefiere inyectar dependencias (como el `GameManager`) en lugar de acceder a singletons fuera de `main.swift`.
- Antes de introducir un nuevo comando, decide si su lógica pertenece a `CLIApplication` o a una nueva capa de servicio.
- Acompaña las nuevas características con documentación breve en este archivo para que otros agentes mantengan una visión compartida.

## Localización
- El idioma por defecto se deduce desde `Locale.preferredLanguages` y cae en español si no se detecta inglés.
- Puedes forzar el idioma exportando `CAPITALIST_LANG` con valores como `en` o `es` antes de ejecutar el binario.
- `Localizable.xcstrings` debe estar marcado en el target CLI para que Xcode empaquete ambas traducciones.
- Los mensajes de Core Data y el prompt utilizan el mismo catálogo para evita inconsistencias.
