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
//  This class This class handles non-trivial operations related to user management, such as:
//    *Logging in a user using email and password.
//    *Managing session persistence via UserDefaults.
//    *Implementing a retry mechanism for network requests during login.
//    *Handling the current user session, including retrieval, storage, and logout.
//
//   The class decouples data management (handled by the User model) from operations, 
//    ensuring a clean separation of responsibilities.
//
//  Key Features:
//    *Manage login with retry on timeout.
//    *Save and retrieve the current user using UserDefaults.
//    *Provide a logout method to clear user session and data.
//    *Loads current user on app startup
//
import Foundation

class UserOperations {
    // MARK: - Constants
    static let loginAPI = "api/login.php"       // https://app_domain/api/login
    static let logoutAPI = "api/logout.php"       // https://app_domain/api/login
    static let userDefaultsFirstNameKey = "currentUserFirstName"
    static let userDefaultsLastNameKey = "currentUserLastName"
    static let userDefaultsEmailKey = "currentUserEmail"
    static let userDefaultsPasswordHashKey = "currentUserPasswordHash"
    static let userDefaultsUserIDKey = "currentUserUserID"
    
    // MARK: - Enum for User State
    enum UserState {
        case notLoggedIn
        case pendingVerification      
        case verified
    }
    
    // MARK: - Static Current User State Management
    static var currentUserState: UserState = {
        return currentUser == nil ? .notLoggedIn : .verified
    }()
    
    // Static variable to hold the current user and load from UserDefaults
    static var currentUser: User? = {
        let user = readCurrentUser()
        currentUserState = user == nil ? .notLoggedIn : .verified
        return user
    }()
    
    // MARK: - Async Login
    static func loginUser(email: String, password: String) async -> Void {
        currentUserState = .pendingVerification

        let hashedPassword = User.hashPassword(password) // (firstName: "", lastName: "", email: email, userID: "", password: password).verifyPassword(password) ? password : ""
        
        // Create the URL with the query parameters (email and hashed password)
        var urlComponents = URLComponents.initAPI(path: loginAPI)
        urlComponents.queryItems = [
            URLQueryItem(name: "email", value: email),
            URLQueryItem(name: "password", value: hashedPassword)
        ]
        
         MonitoredAPICall().callAPIWithCompletion(urlComponents: urlComponents, priority: .high) { result in
              // This code will be executed on the main thread for high-priority calls
             if result.success {
                 print("High priority API call successful!")
                 if let data = result.data, let responseString = String(data: data, encoding: .utf8) {
                     print("Response Data: \(responseString)")
                     
                     // Parse the response (assuming JSON format with fields: firstName, lastName, userID)
                     if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                        let firstName = json["firstName"],
                        let lastName = json["lastName"],
                        let userID = json["userID"] {
                         
                         let user = User(firstName: firstName, lastName: lastName, email: email, userID: userID, password: hashedPassword)
                         currentUser = user
                         currentUserState = .verified
                     } else {
                         currentUserState = .notLoggedIn
                     }
                 }
             } else {
                 print("High priority API call failed.")
                 currentUserState = .notLoggedIn
             }
         }
    }
    
    
    // MARK: - Logout Method
    static func logout() {
        if currentUserState != .verified || currentUser == nil {
            // this may be an error: how are we getting to "log out" if not logged in?
            return;
        }
        
        // tell server user is logged out
        
        // Create the URL with the query parameters (email and hashed password)
        var urlComponents = URLComponents.initAPI(path: logoutAPI)
        urlComponents.queryItems = [
            URLQueryItem(name: "userID", value: currentUser?.userID ?? ""),
        ]
        
        MonitoredAPICall().callAPIWithCompletion(urlComponents: urlComponents, priority: .high) { result in
            // This code will be executed on the main thread for high-priority calls
            if result.success {
                // really not much to do for success.
                clearCurrentUser()
                currentUser = nil
                currentUserState = .notLoggedIn
                print("User logged out. All stored data cleared.")
            } else {
                currentUserState = .notLoggedIn
            }
        }
    }
        

    // MARK: - UserDefaults Operations

    private static func readCurrentUser() -> User? {
        let defaults = UserDefaults.standard
        guard let firstName = defaults.string(forKey: userDefaultsFirstNameKey),
              let lastName = defaults.string(forKey: userDefaultsLastNameKey),
              let email = defaults.string(forKey: userDefaultsEmailKey),
              let userID = defaults.string(forKey: userDefaultsUserIDKey),
              let passwordHash = defaults.string(forKey: userDefaultsPasswordHashKey) else {
            return nil
        }
        let user = User(firstName: firstName, lastName: lastName, email: email, userID: userID, password: "")
        user.updatePassword(newPassword: passwordHash) // Password is read as hash, not plain text
        return user
    }
    
    private static func saveCurrentUser(user: User) {
        let defaults = UserDefaults.standard
        defaults.set(user.firstName, forKey: userDefaultsFirstNameKey)
        defaults.set(user.lastName, forKey: userDefaultsLastNameKey)
        defaults.set(user.email, forKey: userDefaultsEmailKey)
        defaults.set(user.userID, forKey: userDefaultsUserIDKey)
        defaults.set(user.anonymousID(), forKey: userDefaultsPasswordHashKey)
    }
    
    private static func clearCurrentUser() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: userDefaultsFirstNameKey)
        defaults.removeObject(forKey: userDefaultsLastNameKey)
        defaults.removeObject(forKey: userDefaultsEmailKey)
        defaults.removeObject(forKey: userDefaultsUserIDKey)
        defaults.removeObject(forKey: userDefaultsPasswordHashKey)
    }
}
