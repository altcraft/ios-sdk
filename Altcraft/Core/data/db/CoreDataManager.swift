//
//  CoreDataManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

/**
 A Core Data stack manager scoped to one SDK module.

 Each SDK module owns its own `CoreDataManager` instance and therefore its own
 persistent container and store file. Core provides only the mechanism: the
 module itself instantiates the manager with its own model and store names.

 * `CoreDataManager.shared`  — Core module   (`Core.sqlite`)

 Optional modules (Push, Profile, InApp, Target) create their own internal
 instances, e.g. `CoreDataManager(modelName: "Push", storeFileName: "Push.sqlite")`.

 The model is loaded from the Swift Package resources (`Bundle.module`) or the
 framework/app bundle (depending on build) and the SQLite store is placed in
 the shared App Group container when one is configured, otherwise in the app's
 document directory.
 */
@_spi(_Altcraft) public final class CoreDataManager: @unchecked Sendable {

    /// Core module stack.
    public static let shared = CoreDataManager(
        modelName: Constants.CoreData.coreModelName,
        storeFileName: Constants.CoreData.coreStoreFileName
    )

    /// The App Group identifier captured when this stack was created.
    ///
    /// The value is resolved once, at container creation time, from the
    /// explicit `appGroup` argument or the stored App Group setting. `nil`
    /// when no group is configured; the store then lives in the app's
    /// local Documents directory.
    public let groupId: String?

    /// The persistent container for this module's Core Data stack.
    public let persistentContainer: NSPersistentContainer

    /// JSON diagnostic file (App Support) used to collect physical-device info.
    private static var diagnosticsFileURL: URL {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseDir.appendingPathComponent("sdkModelDiag.json")
    }

    /// Appends a JSON entry to the SDK model diagnostics file.
    ///
    /// Only active in `DEBUG` builds; compile to a no-op for release so the
    /// SDK never performs file I/O on hot paths in production.
    static func appendDiagnostics(_ payload: [String: Any]) {
        #if DEBUG
        let fileURL = diagnosticsFileURL
        let line = (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]))
            .map { String(data: $0, encoding: .utf8) ?? "" } ?? ""
        var log = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        if log.isEmpty {
            log = "[\n"
        } else {
            while log.last == "]" || log.last == "\n" || log.last == " " || log.last == "," {
                log.removeLast()
            }
            log += ",\n"
        }
        log += line + "\n]"
        if let data = log.data(using: .utf8) {
            try? data.write(to: fileURL, options: .atomic)
        }
        #endif
    }

    /// Records the result of loading a module Core Data model (success or
    /// failure), including which bundles were searched and which entities the
    /// loaded model contains.
    private static func persistModelLoadResult(
        _ modelName: String,
        loadedModel: NSManagedObjectModel?,
        candidates: [Bundle]
    ) {
        var payload: [String: Any] = [
            "date": ISO8601DateFormatter().string(from: Date()),
            "modelName": modelName,
            "result": loadedModel == nil ? "MISSING_MODEL" : "LOADED"
        ]
        if let model = loadedModel {
            payload["entityCount"] = model.entities.count
            payload["entities"] = model.entities.map { $0.name ?? "?" }
        }
        payload["searchedBundles"] = candidates.map { bundle -> [String: Any] in
            [
                "bundle": bundle.bundleURL.lastPathComponent,
                "containsModel": bundle.url(forResource: modelName, withExtension: "momd") != nil
                    || bundle.url(forResource: modelName, withExtension: "mom") != nil,
                "momdFound": (bundle.urls(forResourcesWithExtension: "momd", subdirectory: nil) ?? []).map { $0.lastPathComponent },
                "momFound": (bundle.urls(forResourcesWithExtension: "mom", subdirectory: nil) ?? []).map { $0.lastPathComponent }
            ]
        }
        appendDiagnostics(payload)
        if loadedModel == nil {
            CoreLog.error(
                #function,
                error: CoreEvents.coreDataModelNotFoundInBundle,
                eventValue: [
                    "model": modelName,
                    "diagnosticsFile": diagnosticsFileURL.path
                ]
            )
        }
    }

    /// Initializes a module Core Data manager.
    ///
    /// - Parameters:
    ///   - modelName: The name of the `.momd`/`.mom` model for this module.
    ///   - storeFileName: The SQLite store file name for this module.
    ///   - appGroup: Optional App Group ID. If nil, `StoredVariablesManager.shared.getGroupName()` is used.
    public init(modelName: String, storeFileName: String, appGroup: String? = nil) {
        let userDefaults  = StoredVariablesManager.shared
        let resolvedGroup = appGroup ?? userDefaults.getGroupName()
        self.groupId      = resolvedGroup
        let groupId       = resolvedGroup

        let loadModelCandidates: [Bundle] = {
            var candidates: [Bundle] = []

            // 1. Look for the model in the main app bundle (in case it's a flat resource)
            candidates.append(Bundle.main)

            // 2. Look for SPM resource bundles (e.g. AltcraftCore_AltcraftCore.bundle)
            //    and embedded frameworks (.framework) in the main bundle.
            let mainBundlePath = Bundle.main.bundlePath
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: mainBundlePath) {
                for bundleName in contents {
                    let fullPath = URL(fileURLWithPath: mainBundlePath).appendingPathComponent(bundleName)
                    if bundleName.hasSuffix(".bundle"), let bundle = Bundle(url: fullPath) {
                        candidates.append(bundle)
                    }
                }
            }

            // 3. Embedded frameworks in Example.app/Frameworks/
            let frameworksDir = URL(fileURLWithPath: mainBundlePath).appendingPathComponent("Frameworks")
            if let fwContents = try? FileManager.default.contentsOfDirectory(atPath: frameworksDir.path) {
                for fwName in fwContents where fwName.hasSuffix(".framework") {
                    let fwPath = frameworksDir.appendingPathComponent(fwName)
                    if let bundle = Bundle(url: fwPath) {
                        candidates.append(bundle)
                    }
                    // 3b. Resource bundles (e.g. AltcraftPushResources.bundle) may live
                    //     inside each framework's Resources/. Search for nested *.bundle there.
                    let fwResourcesDir = fwPath.appendingPathComponent("Resources")
                    if let resContents = try? FileManager.default.contentsOfDirectory(atPath: fwResourcesDir.path) {
                        for resName in resContents where resName.hasSuffix(".bundle") {
                            if let resBundle = Bundle(url: fwResourcesDir.appendingPathComponent(resName)) {
                                candidates.append(resBundle)
                            }
                        }
                    }
                }
            }

            // 4. Look for AltcraftResources.bundle (in framework or main bundle)
            let frameworkBundle = Bundle(for: CoreDataManager.self)
            if let urlInFramework = frameworkBundle.url(forResource: "AltcraftResources", withExtension: "bundle"),
               let resInFramework = Bundle(url: urlInFramework) {
                candidates.append(resInFramework)
            }

            if let urlInMain = Bundle.main.url(forResource: "AltcraftResources", withExtension: "bundle"),
               let resInMain = Bundle(url: urlInMain) {
                candidates.append(resInMain)
            }

            // 5. SPM module bundle
            #if SWIFT_PACKAGE
            candidates.append(Bundle.module)
            #endif

            // 6. Framework bundle itself
            candidates.append(frameworkBundle)

            // 7. All loaded frameworks (covers test runners and dynamically
            //    loaded SDK frameworks where embedding is not guaranteed).
            for bundle in Bundle.allFrameworks {
                candidates.append(bundle)
            }

            return candidates
        }()

        /// Loads the Core Data model from a single bundle.
        ///
        /// Searches for:
        ///   - `name.momd` (compiled, pre-processed by the build system)
        ///   - `name.mom`  (single compiled model)
        ///   - `name.xcdatamodeld` (source directory, SPM `.process` keeps it as-is)
        ///
        /// For `xcdatamodeld`, `NSManagedObjectModel(contentsOf:)` compiles it on load.
        ///
        /// - Parameter named: The base model name (e.g. "Core", "Push").
        func loadModel(named: String, inBundle bundle: Bundle) -> NSManagedObjectModel? {
            // Try in priority order: .momd, .mom, .xcdatamodeld
            for ext in ["momd", "mom", "xcdatamodeld"] {
                let viaBundle = bundle.url(forResource: named, withExtension: ext)
                let atPath = URL(fileURLWithPath: bundle.bundlePath).appendingPathComponent("\(named).\(ext)")
                let url: URL? = (viaBundle != nil) ? viaBundle : (FileManager.default.fileExists(atPath: atPath.path) ? atPath : nil)
                if let url = url,
                   let model = NSManagedObjectModel(contentsOf: url) {
                    return model
                }
            }
            return nil
        }

        /// Loads the Core Data model (single .momd/.mom) from the first candidate bundle
        /// that contains it.
        func loadModel(named: String) -> NSManagedObjectModel? {
            for bundle in loadModelCandidates {
                if let model = loadModel(named: named, inBundle: bundle) {
                    return model
                }
            }
            return nil
        }

        /// Creates URL for the persistent store inside the App Group **Altcraft**
        /// subdirectory, or Documents/Altcraft as a fallback. Ensures the directory exists.
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
                CoreLog.error(#function, error: error)
            }

            return baseDir.appendingPathComponent(storeFileName)
        }

        /// Builds the option set used when adding the SQLite store.
        /// Enables lightweight migrations and cross-process change propagation.
        func makeStoreOptions() -> [String: Any] {
            var options: [String: Any] = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSPersistentHistoryTrackingKey: true,
                NSPersistentStoreRemoteChangeNotificationPostOptionKey: true
            ]

            let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")
            if isExtension {
                options[NSPersistentStoreFileProtectionKey] = FileProtectionType.none as NSObject
            }
            return options
        }

        /// Adds the SQLite store to the container's coordinator.
        ///
        /// - Returns: `true` when the store was added successfully.
        func addStore(coordinator: NSPersistentStoreCoordinator, at storeURL: URL) -> Bool {
            do {
                try coordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: storeURL,
                    options: makeStoreOptions()
                )
                return true
            } catch {
                CoreLog.error(#function, error: error)
                return false
            }
        }

        /// Removes the store and its auxiliary SQLite files (`-wal`, `-shm`).
        func removeStoreFiles(at storeURL: URL) {
            let fm = FileManager.default
            for url in [
                storeURL,
                URL(fileURLWithPath: storeURL.path + "-wal"),
                URL(fileURLWithPath: storeURL.path + "-shm")
            ] {
                do {
                    if fm.fileExists(atPath: url.path) {
                        try fm.removeItem(at: url)
                    }
                } catch {
                    CoreLog.error(#function, error: error)
                }
            }
        }

        /// Configures the persistent container with the provided model.
        ///
        /// If the store cannot be loaded its SQLite files are removed and the
        /// store is recreated from scratch.
        ///
        /// Per-module critical flag lifecycle:
        /// - An unrecoverable store load failure sets the owning module's
        ///   critical flag, limiting only that module's operations.
        /// - A successful store load (first attempt or after recreate) clears
        ///   the module's flag, so a transient failure from a previous
        ///   session no longer blocks the module after recovery.
        func configureContainer(model: NSManagedObjectModel) -> NSPersistentContainer {
            let container = NSPersistentContainer(name: modelName, managedObjectModel: model)
            let storeURL = makeStoreURL()
            let coordinator = container.persistentStoreCoordinator

            let loaded = addStore(coordinator: coordinator, at: storeURL)
            if !loaded {
                removeStoreFiles(at: storeURL)
            }
            let recovered = loaded || addStore(coordinator: coordinator, at: storeURL)

            if recovered {
                if userDefaults.getDbErrorStatus(module: modelName) {
                    userDefaults.setCritDB(value: false, module: modelName)
                }
            } else {
                userDefaults.setCritDB(value: true, module: modelName)
            }

            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergePolicy(
                merge: .mergeByPropertyObjectTrumpMergePolicyType
            )
            container.viewContext.name = "ViewContext"
            return container
        }

        /// Creates a fallback persistent container with an empty model.
        ///
        /// This is used if the module's Core Data model cannot be loaded,
        /// allowing the app to continue running with a non-functional store.
        func fallbackContainer() -> NSPersistentContainer {
            CoreLog.error(#function, error: CoreEvents.errorLoadModelInCoreData)
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
        Self.persistModelLoadResult(
            modelName,
            loadedModel: persistentContainer.managedObjectModel,
            candidates: loadModelCandidates
        )
    }

    /// Returns a freshly configured private-queue background context.
    public func getContext() -> NSManagedObjectContext {
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
    public func performBackgroundTask<T>(
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

    /// Deletes every managed object of the named entity in this module's store.
    ///
    /// Fetches and deletes one by one (guarding the in-memory stores used by
    /// tests, where `NSBatchDeleteRequest` raises an uncaught exception).
    ///
    /// - Parameter entityName: The Core Data entity name to purge.
    /// - Returns: `true` when the fetch, deletes and save succeeded.
    public func deleteAll(ofEntityNamed entityName: String) async -> Bool {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.automaticallyMergesChangesFromParent = true
        context.undoManager = nil

        do {
            return try await context.performAsync { () -> Bool in
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                let results = try context.fetch(request)
                for object in results {
                    context.delete(object)
                }
                try context.save()
                return true
            }
        } catch {
            CoreLog.error(#function, error: error)
            return false
        }
    }
}

@_spi(_Altcraft) public extension NSManagedObjectContext {
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
