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
final class CoreDataManager {

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
        let storeFileName = Constants.CoreData.storeFileName
        let userDefaults  = StoredVariablesManager.shared
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
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
            if isExtension {
                description.setOption(FileProtectionType.none as NSObject,
                                      forKey: NSPersistentStoreFileProtectionKey)
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
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
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
}

/// Returns a new private-queue background `NSManagedObjectContext`.
///
/// The caller is responsible for performing all Core Data operations
/// inside `context.perform { ... }` or `context.performAndWait { ... }`,
/// and for managing the context’s lifetime.
///
/// Use when several async steps must share one context.
/// For one-off tasks, prefer `withBackgroundContext(_:)`.
func getContext() -> NSManagedObjectContext {
    let ctx = CoreDataManager.shared.persistentContainer.newBackgroundContext()
    ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    ctx.automaticallyMergesChangesFromParent = true
    ctx.undoManager = nil
    return ctx
}

/// Executes a closure with a preconfigured background context.
/// The context is created using `performBackgroundTask`, ensuring all Core Data work
/// runs on a private queue without blocking the main thread.
///
/// The context is configured with:
/// - `NSMergeByPropertyObjectTrumpMergePolicy` for safe merge conflict resolution
/// - `automaticallyMergesChangesFromParent = true` to stay in sync with parent contexts
/// - `undoManager = nil` to reduce memory overhead in background operations
///
/// - Parameter block: A closure receiving a configured `NSManagedObjectContext` to perform Core Data work.
func withBackgroundContext(_ block: @escaping (NSManagedObjectContext) -> Void) {
    CoreDataManager.shared.persistentContainer.performBackgroundTask { ctx in
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        ctx.undoManager = nil
        block(ctx)
    }
}
