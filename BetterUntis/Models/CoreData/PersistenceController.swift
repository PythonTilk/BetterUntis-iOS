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
        // Use programmatic data model instead of .xcdatamodeld file
        // This ensures PeriodEntity and other entities are properly defined
        let managedObjectModel = Self.createDataModel()
        container = NSPersistentContainer(name: "BetterUntis", managedObjectModel: managedObjectModel)

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

        let innerForeColorAttribute = NSAttributeDescription()
        innerForeColorAttribute.name = "innerForeColor"
        innerForeColorAttribute.attributeType = .stringAttributeType
        innerForeColorAttribute.isOptional = true

        let innerBackColorAttribute = NSAttributeDescription()
        innerBackColorAttribute.name = "innerBackColor"
        innerBackColorAttribute.attributeType = .stringAttributeType
        innerBackColorAttribute.isOptional = true

        let lessonTextAttribute = NSAttributeDescription()
        lessonTextAttribute.name = "lessonText"
        lessonTextAttribute.attributeType = .stringAttributeType
        lessonTextAttribute.isOptional = true

        let substitutionTextAttribute = NSAttributeDescription()
        substitutionTextAttribute.name = "substitutionText"
        substitutionTextAttribute.attributeType = .stringAttributeType
        substitutionTextAttribute.isOptional = true

        let infoTextAttribute = NSAttributeDescription()
        infoTextAttribute.name = "infoText"
        infoTextAttribute.attributeType = .stringAttributeType
        infoTextAttribute.isOptional = true

        let periodDataAttribute = NSAttributeDescription()
        periodDataAttribute.name = "periodData"
        periodDataAttribute.attributeType = .binaryDataAttributeType
        periodDataAttribute.allowsExternalBinaryDataStorage = true
        periodDataAttribute.isOptional = true

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
            innerForeColorAttribute,
            innerBackColorAttribute,
            lessonTextAttribute,
            substitutionTextAttribute,
            infoTextAttribute,
            periodDataAttribute,
            userIdForeignKey
        ]

        // Master Data Entity (generic storage for rooms, teachers, subjects, classes)
        let masterDataEntity = NSEntityDescription()
        masterDataEntity.name = "MasterDataEntity"
        masterDataEntity.managedObjectClassName = "MasterDataEntity"

        let masterIdAttribute = NSAttributeDescription()
        masterIdAttribute.name = "id"
        masterIdAttribute.attributeType = .integer64AttributeType
        masterIdAttribute.isOptional = false

        let masterTypeAttribute = NSAttributeDescription()
        masterTypeAttribute.name = "type"
        masterTypeAttribute.attributeType = .stringAttributeType
        masterTypeAttribute.isOptional = false

        let masterNameAttribute = NSAttributeDescription()
        masterNameAttribute.name = "name"
        masterNameAttribute.attributeType = .stringAttributeType
        masterNameAttribute.isOptional = false

        let masterLongNameAttribute = NSAttributeDescription()
        masterLongNameAttribute.name = "longName"
        masterLongNameAttribute.attributeType = .stringAttributeType
        masterLongNameAttribute.isOptional = true

        let masterDisplayNameAttribute = NSAttributeDescription()
        masterDisplayNameAttribute.name = "displayName"
        masterDisplayNameAttribute.attributeType = .stringAttributeType
        masterDisplayNameAttribute.isOptional = true

        let masterAlternateNameAttribute = NSAttributeDescription()
        masterAlternateNameAttribute.name = "alternateName"
        masterAlternateNameAttribute.attributeType = .stringAttributeType
        masterAlternateNameAttribute.isOptional = true

        let masterBuildingAttribute = NSAttributeDescription()
        masterBuildingAttribute.name = "building"
        masterBuildingAttribute.attributeType = .stringAttributeType
        masterBuildingAttribute.isOptional = true

        let masterForeColorAttribute = NSAttributeDescription()
        masterForeColorAttribute.name = "foreColor"
        masterForeColorAttribute.attributeType = .stringAttributeType
        masterForeColorAttribute.isOptional = true

        let masterBackColorAttribute = NSAttributeDescription()
        masterBackColorAttribute.name = "backColor"
        masterBackColorAttribute.attributeType = .stringAttributeType
        masterBackColorAttribute.isOptional = true

        let masterActiveAttribute = NSAttributeDescription()
        masterActiveAttribute.name = "active"
        masterActiveAttribute.attributeType = .booleanAttributeType
        masterActiveAttribute.isOptional = true

        let masterCanViewAttribute = NSAttributeDescription()
        masterCanViewAttribute.name = "canViewTimetable"
        masterCanViewAttribute.attributeType = .booleanAttributeType
        masterCanViewAttribute.isOptional = true

        let masterUserIdAttribute = NSAttributeDescription()
        masterUserIdAttribute.name = "userId"
        masterUserIdAttribute.attributeType = .integer64AttributeType
        masterUserIdAttribute.isOptional = false

        masterDataEntity.properties = [
            masterIdAttribute,
            masterTypeAttribute,
            masterNameAttribute,
            masterLongNameAttribute,
            masterDisplayNameAttribute,
            masterAlternateNameAttribute,
            masterBuildingAttribute,
            masterForeColorAttribute,
            masterBackColorAttribute,
            masterActiveAttribute,
            masterCanViewAttribute,
            masterUserIdAttribute
        ]

        model.entities = [userEntity, periodEntity, masterDataEntity]

        return model
    }
}
