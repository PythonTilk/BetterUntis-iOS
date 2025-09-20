import CoreData
import Foundation

@objc(UserEntity)
public class UserEntity: NSManagedObject {

}


extension UserEntity {

    func toDomainModel() -> User {
        return User(
            id: self.id,
            profileName: self.profileName ?? "",
            apiHost: self.apiHost ?? "",
            displayName: self.displayName ?? "",
            schoolName: self.schoolName ?? "",
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
struct User: Identifiable, Equatable {
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

    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id &&
               lhs.profileName == rhs.profileName &&
               lhs.apiHost == rhs.apiHost &&
               lhs.displayName == rhs.displayName &&
               lhs.schoolName == rhs.schoolName &&
               lhs.anonymous == rhs.anonymous &&
               lhs.masterDataTimestamp == rhs.masterDataTimestamp &&
               lhs.created == rhs.created
    }
}