import CoreData
import Foundation

@objc(UserEntity)
public class UserEntity: NSManagedObject {

}

extension UserEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserEntity> {
        return NSFetchRequest<UserEntity>(entityName: "UserEntity")
    }

    @NSManaged public var id: Int64
    @NSManaged public var profileName: String?
    @NSManaged public var apiHost: String
    @NSManaged public var displayName: String
    @NSManaged public var schoolName: String
    @NSManaged public var anonymous: Bool
    @NSManaged public var masterDataTimestamp: Int64
    @NSManaged public var created: Date?

}

extension UserEntity {

    func toDomainModel() -> User {
        return User(
            id: self.id,
            profileName: self.profileName ?? "",
            apiHost: self.apiHost,
            displayName: self.displayName,
            schoolName: self.schoolName,
            anonymous: self.anonymous,
            masterDataTimestamp: self.masterDataTimestamp,
            created: self.created
        )
    }

    func update(from user: User) {
        self.id = user.id
        self.profileName = user.profileName.isEmpty ? nil : user.profileName
        self.apiHost = user.apiHost
        self.displayName = user.displayName
        self.schoolName = user.schoolName
        self.anonymous = user.anonymous
        self.masterDataTimestamp = user.masterDataTimestamp
        self.created = user.created
    }
}

// Domain model for User
struct User: Identifiable {
    let id: Int64
    let profileName: String
    let apiHost: String
    let displayName: String
    let schoolName: String
    let anonymous: Bool
    let masterDataTimestamp: Int64
    let created: Date?

    func getDisplayedName() -> String {
        if !profileName.isEmpty {
            return profileName
        } else if anonymous {
            return "Anonymous"
        } else {
            return displayName
        }
    }
}