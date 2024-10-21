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
//  This class will handle HTTPS API calls, include a timeout, retry logic (3 retries), 
//   and monitor stats like time taken, retries, and failure.  Statistics are provided
//   to the APIStats class for tracking.
//   
//  Key Features:
//    *.high priority calls to callAPIWithCommpletion automatically have the results
//     processing performed on the main thread to ensure UI thread safety.
// 
// Example Usage using "await" for results:
//
// Task {
//     // Create an instance of APIURLComponents, automatically fills in scheme and host
//     let apiURLComponents = APIURLComponents()
//     apiURLComponents.path = "/api/endpoint"
//     apiURLComponents.queryItems = [
//         URLQueryItem(name: "param1", value: "value1"),
//         URLQueryItem(name: "param2", value: "value2")
//     ]
//     // Call the API with high priority (short timeout)
//     let result = await MonitoredAPICall().callAPI(urlComponents: apiURLComponents, priority: .high)
//     if result.success {
//         print("High priority API call successful!")
//         if let data = result.data, let responseString = String(data: data, encoding: .utf8) {
//             // process response data
//             print("Response Data: \(responseString)")
//         }
//     } else {
//         print("High priority API call failed.")
//     }
// }
// 
// Example Usage with completion block:
//
// let apiURLComponents = APIURLComponents()
// apiURLComponents.path = "/api/endpoint"
// apiURLComponents.queryItems = [
//     URLQueryItem(name: "param1", value: "value1"),
//     URLQueryItem(name: "param2", value: "value2")
// ]
// MonitoredAPICall().callAPIWithCompletion(urlComponents: apiURLComponents, priority: .high) { result in
//      // This code will be executed on the main thread for high-priority calls
//     if result.success {
//         print("High priority API call successful!")
//         if let data = result.data, let responseString = String(data: data, encoding: .utf8) {
//             print("Response Data: \(responseString)")
//         }
//     } else {
//         print("High priority API call failed.")
//     }
// }

import Foundation

// Constants for timeouts
let shortTimeoutInterval: TimeInterval = 1.5 // 1.5-second timeout for high priority calls
let longTimeoutInterval: TimeInterval = 10.0 // 10-second timeout for low priority calls
let maxRetries = 3
let statusCodeRetryable = [500, 502, 503, 504] // Retry on server errors

class MonitoredAPICall {

    enum Priority {
        case high
        case low
    }

    var retries: Int = 0
    var timeTaken: TimeInterval = 0.0
    var success: Bool = false
    var completed: Bool = false
    
    // Custom Result type to include both success status and response data
    struct APICallResult {
        let success: Bool
        let data: Data?
    }
  
    // async version of callAPI that takes APIURLComponents and Priority
    // and returns the success status along with the response data
    // Updated callAPI with an optional `shouldSendStats` parameter
    func callAPI(urlComponents: URLComponents, priority: Priority, shouldSendStats: Bool = true) async -> APICallResult {
        let startTime = Date()
        let result = await makeGetRequest(urlComponents: urlComponents, priority: priority)
        self.timeTaken = Date().timeIntervalSince(startTime)
        self.completed = result.success
        self.success = result.success
        // Conditionally send stats unless explicitly disabled (e.g., for APIStats calls)
        if shouldSendStats {
            let stats = APIStats()
            stats.sendStats(timeTaken: self.timeTaken, retries: self.retries, success: self.success, urlComponents: urlComponents)
        }

        return result
    }
    
    // async version of makeRequest that takes APIURLComponents and Priority
    // and returns APICallResult which includes success status and response data
    private func makeGetRequest(urlComponents: URLComponents, priority: Priority) async -> APICallResult {
        let session = URLSession(configuration: .default)
        guard let url = urlComponents.url else {
            print("Invalid URL")
            return APICallResult(success: false, data: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = (priority == .high) ? shortTimeoutInterval : longTimeoutInterval

        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    // Success, return the data
                    return APICallResult(success: true, data: data)
                case 404:
                    print("Error 404: Not Found")
                    return APICallResult(success: false, data: nil)
                case 500:
                    print("Error 500: Internal Server Error")
                    return await handleGetRetry(urlComponents: urlComponents, priority: priority)
                default:
                    if statusCodeRetryable.contains(httpResponse.statusCode) {
                        return await handleGetRetry(urlComponents: urlComponents, priority: priority)
                    } else {
                        return APICallResult(success: false, data: nil)
                    }
                }
            } else {
                return APICallResult(success: false, data: nil)
            }
        } catch {
            // Network error, retry if possible
            return await handleGetRetry(urlComponents: urlComponents, priority: priority)
        }
    }
    
    private func handleGetRetry(urlComponents: URLComponents, priority: Priority) async -> APICallResult {
        if retries < maxRetries {
            retries += 1
            print("Retrying... (\(retries)/\(maxRetries))")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second before retrying
            return await makeGetRequest(urlComponents: urlComponents, priority: priority)
        } else {
            return APICallResult(success: false, data: nil)
        }
    }

    // call API Method using a completion block, processes on main thread if high priority
    func callAPIWithCompletion(urlComponents: URLComponents, priority: Priority,  shouldSendStats: Bool = true, completion: @escaping (APICallResult) -> Void) {
        Task {
            // Reuse the callAPI method
            let result = await self.callAPI(urlComponents: urlComponents, priority: priority, shouldSendStats: shouldSendStats)
            
            // If high priority, ensure the completion block runs on the main thread
            if priority == .high {
                DispatchQueue.main.async {
                    completion(result)
                }
            } else {
                // Low priority, completion block can run on the current background thread
                completion(result)
            }
        }
    }  
}
