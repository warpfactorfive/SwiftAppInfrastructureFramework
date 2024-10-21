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
//  This class implements a subclass for URLComponents so that 
//  users do not specify the scheme or host.
//

import Foundation

extension URLComponents {
    
    // Constants for default scheme and host
    static let defaultScheme = "https"
    static let defaultHost = "example.com"
    
    // A custom initializer that sets default scheme and host
    static func initAPI(path: String, queryItems: [String: String]? = nil) -> URLComponents {
        var components = URLComponents()
        components.scheme = defaultScheme
        components.host = defaultHost
        components.path = path
        if let queryItems = queryItems {
            components.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components
    }
    
//    // Add a method to easily set query items from a dictionary
//    mutating func setQueryItems(from dictionary: [String: String]) {
//        self.queryItems = dictionary.map { URLQueryItem(name: $0.key, value: $0.value) }
//    }
//    
//    // Computed property to get the full URL as a string
//    var fullURLString: String {
//        return self.url?.absoluteString ?? "Invalid URL"
//    }
//    
//    // Method to append a query item to the existing query items
//    mutating func appendQueryItem(name: String, value: String) {
//        var currentQueryItems = self.queryItems ?? []
//        currentQueryItems.append(URLQueryItem(name: name, value: value))
//        self.queryItems = currentQueryItems
//    }
//    
//    // Method to remove a query item by name
//    mutating func removeQueryItem(named name: String) {
//        self.queryItems = self.queryItems?.filter { $0.name != name }
//    }
}
