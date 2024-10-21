//
//  ThreadSafeCollection.swift
//
//  Created by Terry Grossman.
//  
//  Copyright © 2024 Terry Grossman. All rights reserved.  See license file for usage.
//
//  Description:
//  This file contains the implementation of a generic thread-safe collection
//  using Swift actors to ensure safe concurrent access to mutable collections.
//  The collection supports various operations such as appending, sorting, 
//  filtering, and removing elements, while maintaining thread safety.
//
//  Note that operations are considered in FIFO order.  This could be
//  important for operations that read data while a write operation is
//  pending, based on order of operation submission.
//
// Example with Array of Ints:
//     let threadSafeArray = ThreadSafeCollection<Array<Int>>()
//     do {
//         try await threadSafeArray.append(5)
//         try await threadSafeArray.append(10)
//         try await threadSafeOptionalArray.append(nil)
//     } catch {
//         // error handling code here
//     }
// 
//     await threadSafeArray.sort()
//     let sortedArray = await threadSafeArray.allElements()
//     print("Sorted Array: \(sortedArray)")

import Foundation

// Define a custom error type for the ThreadSafeCollection
enum ThreadSafeCollectionError: Error, LocalizedError {
    case nilValueNotAllowed
    case indexOutOfBounds(index: Int)

    var errorDescription: String? {
        switch self {
        case .nilValueNotAllowed:
            return "Error: Cannot append a nil value to the collection."
        case .indexOutOfBounds(let index):
            return "Error: Index \(index) is out of bounds."
        }
    }
}

// Protocol to handle checking if a value is nil in a generic way
protocol OptionalProtocol {
    var isNil: Bool { get }
}

// Extension to make Optional conform to OptionalProtocol
extension Optional: OptionalProtocol {
    var isNil: Bool { self == nil }
}

actor ThreadSafeCollection<CollectionType> where CollectionType: RangeReplaceableCollection {
    private var collection: CollectionType

    init(initialCollection: CollectionType = CollectionType()) {
        self.collection = initialCollection
    }

    // Add an element to the collection (write operation)
    func append(_ element: CollectionType.Element) throws {
        // Ensure we are not appending nil to a collection of optionals
        if let optionalElement = element as? OptionalProtocol, optionalElement.isNil {
            throw ThreadSafeCollectionError.nilValueNotAllowed
        }
        collection.append(element)
    }

    // Get the element at a specific index (read operation, only for collections that support indexing)
    func element(at index: CollectionType.Index) throws -> CollectionType.Element? where CollectionType: RandomAccessCollection {
        guard collection.indices.contains(index) else {
            throw ThreadSafeCollectionError.indexOutOfBounds(index: index as! Int)
        }
        return collection[index]
    }

    // Get all elements (read operation)
    func allElements() -> CollectionType {
        return collection
    }

    // Remove the element at a specific index (write operation, only for collections that support indexing)
    func remove(at index: CollectionType.Index) throws where CollectionType: RangeReplaceableCollection & RandomAccessCollection {
        guard collection.indices.contains(index) else {
            throw ThreadSafeCollectionError.indexOutOfBounds(index: index as! Int)
        }
        collection.remove(at: index)
    }

    // Get the count of the collection (read operation)
    func count() -> Int {
        return collection.count
    }

//    // Sort the collection (write operation, only for collections where the elements are Comparable)
//    func sort() where CollectionType: MutableCollection, CollectionType.Element: Comparable {
//        collection.sort()
//    }
//
//    // Sort the collection with a custom closure (write operation)
//    func sort(by areInIncreasingOrder: (CollectionType.Element, CollectionType.Element) -> Bool) where CollectionType: MutableCollection {
//        collection.sort(by: areInIncreasingOrder)
//    }

    // Filter the collection based on a predicate (read operation, returns new collection)
    func filter(_ isIncluded: (CollectionType.Element) -> Bool) -> CollectionType {
        return collection.filter(isIncluded)
    }
}
