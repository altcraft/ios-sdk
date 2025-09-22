//
//  CoreDataManagerApp.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import CoreData

/**
 A singleton class responsible for managing the Core Data stack.
 */
public class CoreDataManager {

    /// The shared instance of `CoreDataManager`.
    public static let shared = CoreDataManager()

    /// The persistent container for Core Data, which holds the managed object
    /// context and the persistent store coordinator.
    public let persistentContainer: NSPersistentContainer

    /// Initializes the `CoreDataManager` and sets up the Core Data stack.
    ///
    /// - Parameter appGroup: Optional App Group ID. If nil, `StoredVariablesManager.shared.getGroupName()` is used.
    public init(appGroup: String? = nil) {
        
        let modelName = Constants.CoreData.modelName
        let identifier = Constants.CoreData.identifier
        let storeFileName = Constants.CoreData.storeFileName
        let userDefault = StoredVariablesManager.shared
        let group = appGroup ?? userDefault.getGroupName() ?? ""

        /// Loads the Core Data model from the framework bundle.
        func loadModel() -> NSManagedObjectModel? {
            guard let url = Bundle(identifier: identifier)?
                .url(forResource: modelName, withExtension: "momd") else {
                return nil
            }
            return NSManagedObjectModel(contentsOf: url)
        }

        /// Creates a persistent store description for the given App Group and file name.
        func makeStoreDescription() -> NSPersistentStoreDescription? {
            guard let storeURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: group)?
                .appendingPathComponent(storeFileName) else { return nil }
            return NSPersistentStoreDescription(url: storeURL)
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

        /// Returns a closure that handles the load completion of a persistent store.
        func makeStoreLoadHandler() -> (NSPersistentStoreDescription, Error?) -> Void {
            return { _, error in
                userDefault.setCritDB(value: error != nil)
                if let error = error {
                    errorEvent(#function, error: error)
                }
            }
        }

        /// Configures the persistent container with the provided model.
        func configureContainer(
            model: NSManagedObjectModel
        ) -> NSPersistentContainer {
            let box = NSPersistentContainer(name: modelName, managedObjectModel: model)
            if let storeDescription = makeStoreDescription() {
                box.persistentStoreDescriptions = [storeDescription]
            }
            box.loadPersistentStores(completionHandler: makeStoreLoadHandler())
            return box
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
func getContext(completion: @escaping (NSManagedObjectContext) -> Void) {
    CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
        completion(context)
    }
}


    
