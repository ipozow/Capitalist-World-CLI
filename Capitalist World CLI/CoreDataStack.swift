import Foundation
import CoreData

final class CoreDataStack {
    private let modelName = "CapitalistWorldCLI"

    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }

    init() {
        let localization = Localization.shared
        let model = NSManagedObjectModel()
        model.entities = [Game.entityDescription()]

        container = NSPersistentContainer(name: modelName, managedObjectModel: model)
        container.persistentStoreDescriptions = [Self.makeStoreDescription(modelName: modelName)]

        var storeError: Error?
        container.loadPersistentStores { _, error in
            storeError = error
        }

        if let storeError {
            fatalError(localization.coreDataLoadErrorMessage(storeError))
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func saveIfNeeded() throws {
        guard context.hasChanges else { return }
        try context.save()
    }

    private static func makeStoreDescription(modelName: String) -> NSPersistentStoreDescription {
        let storageURL = storageDirectory().appendingPathComponent("\(modelName).sqlite")
        let description = NSPersistentStoreDescription(url: storageURL)
        description.type = NSSQLiteStoreType
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        return description
    }

    private static func storageDirectory() -> URL {
        let localization = Localization.shared
        let fileManager = FileManager.default
        do {
            let base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = base.appendingPathComponent("CapitalistWorldCLI", isDirectory: true)
            if fileManager.fileExists(atPath: directory.path) == false {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            return directory
        } catch {
            fatalError(localization.dataDirectoryErrorMessage(error))
        }
    }
}
