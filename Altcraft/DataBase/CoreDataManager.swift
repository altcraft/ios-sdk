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
 (`Bundle.module`) or the framework/app bundle (depending on build),
 and configures a persistent container. If an App Group ID is
 provided, the SQLite store will be placed in the shared container; otherwise,
 it falls back to the app’s document directory.
 */
final class CoreDataManager: @unchecked Sendable {

    /// The shared instance of `CoreDataManager`.
    public static let shared = CoreDataManager()

    /// The persistent container for Core Data, which holds the managed object
    /// context and the persistent store coordinator.
    let persistentContainer: NSPersistentContainer

    /// Initializes the `CoreDataManager` and sets up the Core Data stack.
    ///
    /// - Parameter appGroup: Optional App Group ID. If nil, `StoredVariablesManager.shared.getGroupName()` is used.
    init(appGroup: String? = nil) {
        let modelName     = Constants.CoreData.modelName
        let userDefaults  = StoredVariablesManager.shared
        let storeFileName = Constants.CoreData.storeFileName
        let groupId       = appGroup ?? userDefaults.getGroupName()
        
        /// Loads the Core Data model (single .momd/.mom) from bundle, without using mergedModel.
        ///
        /// We explicitly load exactly one model by name to avoid duplicate entities
        /// and ambiguity warnings.
        func loadModel(named: String) -> NSManagedObjectModel? {
            var candidates: [Bundle] = []

            let frameworkBundle = Bundle(for: CoreDataManager.self)
            if let urlInFramework = frameworkBundle.url(forResource: "AltcraftResources", withExtension: "bundle"),
               let resInFramework = Bundle(url: urlInFramework) {
                candidates.append(resInFramework)
            }

            if let urlInMain = Bundle.main.url(forResource: "AltcraftResources", withExtension: "bundle"),
               let resInMain = Bundle(url: urlInMain) {
                candidates.append(resInMain)
            }

            #if SWIFT_PACKAGE
            candidates.append(Bundle.module)
            #endif

            candidates.append(frameworkBundle)
            candidates.append(Bundle.main)

            for bundle in candidates {
                if let url = bundle.url(forResource: named, withExtension: "momd"),
                   let model = NSManagedObjectModel(contentsOf: url) {
                    return model
                }
                if let url = bundle.url(forResource: named, withExtension: "mom"),
                   let model = NSManagedObjectModel(contentsOf: url) {
                    return model
                }
            }
            return nil
        }

        /// Creates URL for persistent store inside App Group **Altcraft** subdirectory,
        /// or Documents/Altcraft as a fallback. Ensures directory exists.
        func makeStoreURL() -> URL {
            let fm = FileManager.default
            let subdirName = Constants.CoreData.subdirName

            let baseDir: URL = {
                if let groupId, !groupId.isEmpty,
                   let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: groupId) {
                    return groupURL.appendingPathComponent(subdirName, isDirectory: true)
                } else {
                    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
                    return docs.appendingPathComponent(subdirName, isDirectory: true)
                }
            }()

            do {
                try fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
            } catch {
                errorEvent(#function, error: error)
            }

            return baseDir.appendingPathComponent(storeFileName)
        }

        /// Creates a persistent store description for the given store URL.
        /// Enables lightweight migrations and cross-process change propagation.
        func makeStoreDescription(for storeURL: URL) -> NSPersistentStoreDescription {
            let description = NSPersistentStoreDescription(url: storeURL)
            description.type = NSSQLiteStoreType
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true

            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(
                true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
            )

            let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
            if isExtension {
                description.setOption(
                    FileProtectionType.none as NSObject,
                    forKey: NSPersistentStoreFileProtectionKey
                )
            }
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
            let storeURL = makeStoreURL()
            
            container.persistentStoreDescriptions = [makeStoreDescription(for: storeURL)]
            container.loadPersistentStores(completionHandler: makeStoreLoadHandler())

            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergePolicy(
                merge: .mergeByPropertyObjectTrumpMergePolicyType
            )
            container.viewContext.name = "ViewContext"
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

        if let model = loadModel(named: modelName) {
            persistentContainer = configureContainer(model: model)
        } else {
            persistentContainer = fallbackContainer()
        }
    }
    
    func getContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(
            merge: .mergeByPropertyObjectTrumpMergePolicyType
        )
        context.automaticallyMergesChangesFromParent = true
        context.undoManager = nil
        return context
    }
    
    /// Executes work on a new configured background Core Data context.
    ///
    /// Creates a private background `NSManagedObjectContext`, applies standard SDK configuration,
    /// runs `block` on that context's queue, and returns its result.
    ///
    /// - Parameter block: A closure that performs Core Data work using the provided background context.
    /// - Returns: The value returned by `block`.
    /// - Throws: Any error thrown by `block`.
    func performBackgroundTask<T>(
        _ block: @Sendable @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.automaticallyMergesChangesFromParent = true
        context.undoManager = nil

        return try await context.performAsync {
            try block(context)
        }
    }
}

extension NSManagedObjectContext {

    /// Executes work on the context queue and returns a value.
    ///
    /// - Parameter block: Work executed on the context queue.
    /// - Returns: Value returned by `block`.
    func performAsync<T>(
        _ block: @Sendable @escaping () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            self.perform { @Sendable in
                do {
                    cont.resume(returning: try block())
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}
