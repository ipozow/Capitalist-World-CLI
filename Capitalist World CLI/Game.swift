import Foundation
import CoreData

enum GameStatus: String {
    case active
    case abandoned
}

@objc(Game)
final class Game: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var status: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var lastSavedAt: Date
}

extension Game {
    static func entityDescription() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "Game"
        entity.managedObjectClassName = NSStringFromClass(Game.self)

        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false

        let nameAttribute = NSAttributeDescription()
        nameAttribute.name = "name"
        nameAttribute.attributeType = .stringAttributeType
        nameAttribute.isOptional = false

        let statusAttribute = NSAttributeDescription()
        statusAttribute.name = "status"
        statusAttribute.attributeType = .stringAttributeType
        statusAttribute.isOptional = false

        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = false

        let updatedAtAttribute = NSAttributeDescription()
        updatedAtAttribute.name = "updatedAt"
        updatedAtAttribute.attributeType = .dateAttributeType
        updatedAtAttribute.isOptional = false

        let lastSavedAtAttribute = NSAttributeDescription()
        lastSavedAtAttribute.name = "lastSavedAt"
        lastSavedAtAttribute.attributeType = .dateAttributeType
        lastSavedAtAttribute.isOptional = false

        entity.properties = [
            idAttribute,
            nameAttribute,
            statusAttribute,
            createdAtAttribute,
            updatedAtAttribute,
            lastSavedAtAttribute
        ]

        return entity
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<Game> {
        NSFetchRequest<Game>(entityName: "Game")
    }

    var gameStatus: GameStatus {
        get { GameStatus(rawValue: status) ?? .active }
        set { status = newValue.rawValue }
    }
}
