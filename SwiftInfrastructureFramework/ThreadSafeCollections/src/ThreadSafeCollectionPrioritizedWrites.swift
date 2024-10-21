//
//  ThreadSafeCollectionPrioritizedWrites.swift
//
//  Created by Terry Grossman on 10/18/2024.
//  
//  Copyright © 2024 Terry Grossman. All rights reserved.
//
//  Description:
//  This file contains the implementation of a generic thread-safe collection
//  using Swift actors to ensure safe concurrent access to mutable collections.
//  The collection supports various operations such as appending, sorting, 
//  filtering, and removing elements, while maintaining thread safety.
//
// This code prioritizes WRITE operations over READ operations.  The 
// impact is that if multiple read operations are pending, a write 
// operation will block them until the write is completed.

import Foundation

actor ThreadSafeCollectionPrioritizedWrites<CollectionType> where CollectionType: RangeReplaceableCollection {
    private var collection: CollectionType
    private let queue = DispatchQueue(label: "com.example.threadSafeCollection.prioritizedWrites", attributes: .concurrent)
    private var activeReaders = 0
    private var writePending = false

    init(initialCollection: CollectionType = CollectionType()) {
        self.collection = initialCollection
    }

    // Add an element to the collection (write operation)
    func append(_ element: CollectionType.Element) async {
        await writeOperation {
            self.collection.append(element)
        }
    }

    // Get the element at a specific index (read operation)
    func element(at index: CollectionType.Index) async -> CollectionType.Element? where CollectionType: RandomAccessCollection {
        return await readOperation {
            guard self.collection.indices.contains(index) else { return nil }
            return self.collection[index]
        }
    }

    // Get all elements (read operation)
    func allElements() async -> CollectionType {
        return await readOperation {
            return self.collection
        }
    }

    // Remove the element at a specific index (write operation)
    func remove(at index: CollectionType.Index) async {
        await writeOperation {
            guard self.collection.indices.contains(index) else { return }
            self.collection.remove(at: index)
        }
    }

    // Get the count of the collection (read operation)
    func count() async -> Int {
        return await readOperation {
            return self.collection.count
        }
    }

//    // Sort the collection (write operation)
//    func sort() async {
//        await writeOperation {
//            guard self.collection.count > 1 else { return }
//            if let collection = self.collection as? MutableCollection, let comparableCollection = collection as? [CollectionType.Element] where CollectionType.Element: Comparable {
//                comparableCollection.sort()
//            }
//        }
//    }

//    // Sort the collection with a custom closure (write operation)
//    func sort(by areInIncreasingOrder: @escaping (CollectionType.Element, CollectionType.Element) -> Bool) async {
//        await writeOperation {
//            guard self.collection.count > 1 else { return }
//            if let collection = self.collection as? MutableCollection {
//                collection.sort(by: areInIncreasingOrder)
//            }
//        }
//    }

    // Filter the collection based on a predicate (read operation)
    func filter(_ isIncluded: @escaping (CollectionType.Element) -> Bool) async -> CollectionType {
        return await readOperation {
            return self.collection.filter(isIncluded)
        }
    }

    // Helper for read operations
    private func readOperation<T>(operation: @escaping () -> T) async -> T {
        return await withCheckedContinuation { continuation in
            queue.async {
                self.activeReaders += 1
                continuation.resume(returning: operation())
                self.activeReaders -= 1
                if self.writePending && self.activeReaders == 0 {
                    self.queue.sync(flags: .barrier) {} // Ensure writers can proceed
                }
            }
        }
    }

    // Helper for write operations
    private func writeOperation(operation: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.writePending = true
                while self.activeReaders > 0 {
                    // Wait for all readers to finish
                }
                operation()
                self.writePending = false
                continuation.resume()
            }
        }
    }
}
