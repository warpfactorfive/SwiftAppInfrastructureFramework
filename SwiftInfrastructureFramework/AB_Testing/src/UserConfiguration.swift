//
//  UserConfiguration.swift
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
//  This class implements a network-backed key-value store for boolean values. It fetches
//  a dictionary of boolean values from a given HTTPS URL, stores it in-memory, and
//  persists it to the local filesystem. The stored values are accessible through a
//  singleton instance, ensuring that the data is available throughout the app lifecycle.
//
//  Key Features:
//  - Loads key-value pairs from the network on app launch and when the app becomes active.
//  - Caches the key-value pairs locally on disk for persistence across app sessions.
//  - Provides a method to retrieve boolean values by key, returning `false` if the key
//    does not exist in the dictionary.
//  - Handles network timeouts and provides a configurable timeout interval.
//
//  Usage Example:
//  ```swift
//  let value = UserConfiguration.shared.getValue(forKey: "someKey")
//  print("Value for 'someKey': \(value)")  // Prints the value, or `false` if not found
//  ```
//
//  Configuration:
//  - Network URL, timeout interval, and the name of the on-disk file can be easily modified 
//    by updating the respective constants defined near the top of the file.
//
//  License:
//  [Optional: Add any license information if needed]
//

import UIKit

class UserConfiguration {
    // Static shared instance, initialized once
    static let shared: UserConfiguration = UserConfiguration()
    
    // Base URL for the network request (without query parameters)
    private let baseNetworkURLString = "https://example.com/data.json"
    private let networkTimeoutInterval: TimeInterval = 1.5
    private let onDiskFileName = "keyValueStore.json"
    
    private var dictionary: [String: Bool] = [:]
    private let diskFilePath: URL
    
    private init() {
        // Initialize the file path for saving to disk
        let fileManager = FileManager.default
        if let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            diskFilePath = docsDir.appendingPathComponent(onDiskFileName)
        } else {
            fatalError("Unable to access document directory for saving.")
        }
        
        // Load from disk on init
        loadFromDisk()
        
        // Register for app lifecycle notifications
        registerForAppNotifications()
        
        // Load from network immediately after initialization
        loadDataFromNetwork()
    }
    
    // Register for notifications to detect app lifecycle events
    private func registerForAppNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    // Called when the app becomes active (foreground)
    @objc private func handleAppBecomeActive() {
        print("App became active (foreground)")
        loadDataFromNetwork()
    }
    
    // Stub for generating the user hash
    private func getUserHash() -> String {
        return "stubbedUserHash12345"  // Placeholder user hash for now
    }
    
    // Public method to get a value from the dictionary, returning false if the key is not present
    public func getValue(forKey key: String) -> Bool {
        return dictionary[key] ?? false
    }
    
    // Fetch data from the network with a timeout and user hash
    private func loadDataFromNetwork() {
        let userHash = getUserHash()
        guard var urlComponents = URLComponents(string: baseNetworkURLString) else {
            print("Invalid base URL string.")
            return
        }
        
        // Add the userhash as a query parameter
        urlComponents.queryItems = [URLQueryItem(name: "userhash", value: userHash)]
        
        guard let url = urlComponents.url else {
            print("Failed to construct URL with userhash.")
            return
        }
        
        // Configure URLSession with a timeout interval
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = networkTimeoutInterval
        
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Failed to load data from network: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data received from server.")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Bool] {
                    self.dictionary = json
                    self.saveToDisk()
                    print("Successfully loaded and saved data from network.")
                } else {
                    print("Invalid JSON format.")
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
        
        task.resume()
    }
    
    // Save dictionary to disk
    private func saveToDisk() {
        do {
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            try data.write(to: diskFilePath)
        } catch {
            print("Error saving data to disk: \(error)")
        }
    }
    
    // Load dictionary from disk
    private func loadFromDisk() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: diskFilePath.path) {
            do {
                let data = try Data(contentsOf: diskFilePath)
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Bool] {
                    dictionary = json
                } else {
                    print("Invalid JSON format in file")
                }
            } catch {
                print("Error loading data from disk: \(error)")
            }
        } else {
            print("No file found on disk, starting with empty dictionary.")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
