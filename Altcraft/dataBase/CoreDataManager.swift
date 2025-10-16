//
//  CoreDataManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation
import CoreData

/**
 A singleton class responsible for managing the Core Data stack.
 
 This implementation loads the Core Data model from the Swift Package resources
 (`Bundle.module`) and configures a persistent container. If an App Group ID is
 provided, the SQLite store will be placed in the shared container; otherwise,
 it falls back to the app’s document directory.
 */
public final class CoreDataManager {
    
    /// The shared instance of `CoreDataManager`.
    public static let shared = CoreDataManager()
    
    /// The persistent container for Core Data, which holds the managed object
    /// context and the persistent store coordinator.
    public let persistentContainer: NSPersistentContainer
    
    /// Initializes the `CoreDataManager` and sets up the Core Data stack.
    ///
    /// - Parameter appGroup: Optional App Group ID. If nil, `StoredVariablesManager.shared.getGroupName()` is used.
    public init(appGroup: String? = nil) {
        
        let modelName     = Constants.CoreData.modelName
        let storeFileName = Constants.CoreData.storeFileName   
        let userDefaults  = StoredVariablesManager.shared
        let group         = appGroup ?? userDefaults.getGroupName()
        
        /// Loads the Core Data model from the Swift Package bundle.
        func loadModel() -> NSManagedObjectModel? {
            #if SWIFT_PACKAGE
            // When used inside a Swift Package, always load from Bundle.module
            return NSManagedObjectModel.mergedModel(from: [Bundle.module])
            #else
            // Fallback for framework/app targets
            let bundle = Bundle(for: CoreDataManager.self)
            return NSManagedObjectModel.mergedModel(from: [bundle])
            #endif
        }
        
        /// Creates a persistent store description for the given App Group and file name.
        func makeStoreDescription() -> NSPersistentStoreDescription {
            let storeURL: URL
            if let group, !group.isEmpty,
               let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
                storeURL = groupURL.appendingPathComponent(storeFileName)
            } else {
                let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                storeURL = docURL.appendingPathComponent(storeFileName)
            }
            let description = NSPersistentStoreDescription(url: storeURL)
            description.type = NSSQLiteStoreType
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            return description
        }
        
        /// Returns a closure that handles the load completion of a persistent store.
        func makeStoreLoadHandler() -> (NSPersistentStoreDescription, Error?) -> Void {
            return { _, error in
                userDefaults.setCritDB(value: error != nil)
                if let error = error {
                    errorEvent(#function, error: error)
                }
            }
        }
        
        /// Configures the persistent container with the provided model.
        func configureContainer(model: NSManagedObjectModel) -> NSPersistentContainer {
            let container = NSPersistentContainer(name: modelName, managedObjectModel: model)
            container.persistentStoreDescriptions = [makeStoreDescription()]
            container.loadPersistentStores(completionHandler: makeStoreLoadHandler())
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            return container
        }
        
        /// Creates a fallback persistent container with an empty model.
        ///
        /// This is used if the actual Core Data model cannot be loaded,
        /// allowing the app to continue running with a non-functional store.
        func fallbackContainer() -> NSPersistentContainer {
            errorEvent(#function, error: errorLoadModelInCoreData)
            return NSPersistentContainer(
                name: Constants.CoreData.emptyModelName,
                managedObjectModel: NSManagedObjectModel()
            )
        }
        
        if let model = loadModel() {
            persistentContainer = configureContainer(model: model)
        } else {
            persistentContainer = fallbackContainer()
        }
    }
}

/// Retrieves a background context for performing Core Data operations in a background thread.
///
/// This function executes the provided completion closure with a background context
/// from Core Data's persistent container, allowing you to perform background tasks
/// without blocking the main thread.
///
/// - Parameter completion: A closure that takes an `NSManagedObjectContext` as an argument.
///   This closure is executed once the background context is ready for use.
public func getContext(completion: @escaping (NSManagedObjectContext) -> Void) {
    CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
        completion(context)
    }
}
