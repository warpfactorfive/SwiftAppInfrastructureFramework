//  
//  Created by Terry Grossman.
//
//  This class is part of the Swift infrastructure implementation project.  It provides
//  the code typically required in world-class apps such as Tik-Tok or Instagram:
//    *A/B Testing support based on (anonymized) user id.
//    *Call monitoring 
//    *Crash Diagnostics
//    *Anonymizing users
//
//  This class implements a This class represents the User data model, containing basic
//  user information such as first name, last name, email, and user ID. It also manages
//  secure password hashing, password verification, and generating an anonymous ID for the user.
//

import Foundation
import CryptoKit

class User {
    // MARK: - Properties
    var firstName: String
    var lastName: String
    var email: String
    var userID: String
    private var passwordHash: String?
    
    // MARK: - Initializer
    init(firstName: String, lastName: String, email: String, userID: String, password: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.userID = userID
        self.passwordHash = User.hashPassword(password)
    }
    
    // MARK: - Password Hashing and Verification
    
    // Hash the password using SHA256
    static func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Verify if a given password matches the stored password hash
    func verifyPassword(_ password: String) -> Bool {
        let hashedInput = User.hashPassword(password)
        return hashedInput == self.passwordHash
    }
    
    // Update the password and store the new hash
    func updatePassword(newPassword: String) {
        self.passwordHash = User.hashPassword(newPassword)
    }
    
    // MARK: - Anonymous ID Generation
    func anonymousID() -> String? {
        let userProperties = "\(firstName)\(lastName)\(email)\(userID)"
        guard let data = userProperties.data(using: .utf8) else { return nil }
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
