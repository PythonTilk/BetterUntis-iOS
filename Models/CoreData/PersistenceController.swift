import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Add sample data for previews
        let sampleUser = UserEntity(context: viewContext)
        sampleUser.id = 1
        sampleUser.profileName = "Sample User"
        sampleUser.apiHost = "sample.webuntis.com"
        sampleUser.displayName = "John Doe"
        sampleUser.schoolName = "Sample School"

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BetterUntis")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Core Data Model Extensions
extension PersistenceController {
    static func createDataModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // User Entity
        let userEntity = NSEntityDescription()
        userEntity.name = "UserEntity"
        userEntity.managedObjectClassName = "UserEntity"

        // User attributes
        let userIdAttribute = NSAttributeDescription()
        userIdAttribute.name = "id"
        userIdAttribute.attributeType = .integer64AttributeType
        userIdAttribute.isOptional = false

        let profileNameAttribute = NSAttributeDescription()
        profileNameAttribute.name = "profileName"
        profileNameAttribute.attributeType = .stringAttributeType
        profileNameAttribute.isOptional = true

        let apiHostAttribute = NSAttributeDescription()
        apiHostAttribute.name = "apiHost"
        apiHostAttribute.attributeType = .stringAttributeType
        apiHostAttribute.isOptional = false

        let displayNameAttribute = NSAttributeDescription()
        displayNameAttribute.name = "displayName"
        displayNameAttribute.attributeType = .stringAttributeType
        displayNameAttribute.isOptional = false

        let schoolNameAttribute = NSAttributeDescription()
        schoolNameAttribute.name = "schoolName"
        schoolNameAttribute.attributeType = .stringAttributeType
        schoolNameAttribute.isOptional = false

        let anonymousAttribute = NSAttributeDescription()
        anonymousAttribute.name = "anonymous"
        anonymousAttribute.attributeType = .booleanAttributeType
        anonymousAttribute.isOptional = false

        let masterDataTimestampAttribute = NSAttributeDescription()
        masterDataTimestampAttribute.name = "masterDataTimestamp"
        masterDataTimestampAttribute.attributeType = .integer64AttributeType
        masterDataTimestampAttribute.isOptional = false

        let createdAttribute = NSAttributeDescription()
        createdAttribute.name = "created"
        createdAttribute.attributeType = .dateAttributeType
        createdAttribute.isOptional = true

        userEntity.properties = [
            userIdAttribute,
            profileNameAttribute,
            apiHostAttribute,
            displayNameAttribute,
            schoolNameAttribute,
            anonymousAttribute,
            masterDataTimestampAttribute,
            createdAttribute
        ]

        // Period Entity (for caching timetable data)
        let periodEntity = NSEntityDescription()
        periodEntity.name = "PeriodEntity"
        periodEntity.managedObjectClassName = "PeriodEntity"

        let periodIdAttribute = NSAttributeDescription()
        periodIdAttribute.name = "id"
        periodIdAttribute.attributeType = .integer64AttributeType
        periodIdAttribute.isOptional = false

        let lessonIdAttribute = NSAttributeDescription()
        lessonIdAttribute.name = "lessonId"
        lessonIdAttribute.attributeType = .integer64AttributeType
        lessonIdAttribute.isOptional = false

        let startDateTimeAttribute = NSAttributeDescription()
        startDateTimeAttribute.name = "startDateTime"
        startDateTimeAttribute.attributeType = .dateAttributeType
        startDateTimeAttribute.isOptional = false

        let endDateTimeAttribute = NSAttributeDescription()
        endDateTimeAttribute.name = "endDateTime"
        endDateTimeAttribute.attributeType = .dateAttributeType
        endDateTimeAttribute.isOptional = false

        let foreColorAttribute = NSAttributeDescription()
        foreColorAttribute.name = "foreColor"
        foreColorAttribute.attributeType = .stringAttributeType
        foreColorAttribute.isOptional = false

        let backColorAttribute = NSAttributeDescription()
        backColorAttribute.name = "backColor"
        backColorAttribute.attributeType = .stringAttributeType
        backColorAttribute.isOptional = false

        let userIdForeignKey = NSAttributeDescription()
        userIdForeignKey.name = "userId"
        userIdForeignKey.attributeType = .integer64AttributeType
        userIdForeignKey.isOptional = false

        periodEntity.properties = [
            periodIdAttribute,
            lessonIdAttribute,
            startDateTimeAttribute,
            endDateTimeAttribute,
            foreColorAttribute,
            backColorAttribute,
            userIdForeignKey
        ]

        model.entities = [userEntity, periodEntity]

        return model
    }
}