//  
//  Created by Terry Grossman.
//
//  This class is part of the Swift infrastructure implementation project.  It provides
//  the infrastructure code typically required in world-class apps such as Tik-Tok or Instagram:
//    *A/B Testing support based on (anonymized) user id.
//    *Call monitoring 
//    *Crash Diagnostics
//    *Anonymizing users
//
//  This class handles sending call statistics to an API endpoint.
//  In world-class apps this is used to monitor calls and detect 
//  issues that are impacting user experience including but not limited to:
//    * API (server) failures that cause endpoints to fail.
//    * Network issues that cause timeouts.
//    * Back-end database issues that cause timeouts.
//
//  Key Features:
//

import Foundation

// Constants
let statsPath = "recordData.php" // Replace with your actual stats URL

class APIStats {
    
    // Uses MonitoredAPICall to send the stats without reporting stats on itself
    func sendStats(timeTaken: TimeInterval, retries: Int, success: Bool, urlComponents: URLComponents) {
        // Create APIURLComponents for the stats URL
        let statsComponents = URLComponents.initAPI(path: statsPath)
        
        let statsData: [String: Any] = [
            "timeTaken": timeTaken,
            "retries": retries,
            "success": success,
            "urlComponents": urlComponentsAsDictionary(urlComponents: urlComponents)
        ]
        
        // Serialize statsData to JSON
        guard let statsString = try? JSONSerialization.data(withJSONObject: statsData, options: []) else {
            return
        }
        
        //statsComponents.queryItems = [URLQueryItem(name: "callStats", value: statsString)]
        
        // Send the request using MonitoredAPICall, but skip sending stats for this call (to prevent infinite recursion)
        Task {
            // var monitoredCall = MonitoredAPICall()
            _ = await MonitoredAPICall().callAPI(urlComponents: statsComponents, priority: MonitoredAPICall.Priority.low, shouldSendStats: false) // Disable stats reporting
        }
    }
    
    // Helper method to convert URLComponents into a dictionary for JSON
    private func urlComponentsAsDictionary(urlComponents: URLComponents) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let scheme = urlComponents.scheme {
            dict["scheme"] = scheme
        }
        if let host = urlComponents.host {
            dict["host"] = host
        }

            dict["path"] = urlComponents.path

        if let queryItems = urlComponents.queryItems {
            dict["queryItems"] = queryItems.map { ["name": $0.name, "value": $0.value ?? ""] }
        }
        if let port = urlComponents.port {
            dict["port"] = port
        }
        
        return dict
    }
}
