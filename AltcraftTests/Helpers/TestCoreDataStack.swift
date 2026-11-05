//
//  TestCoreDataStack.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import CoreData
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftPush)
@_spi(_Altcraft) import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@_spi(_Altcraft) import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@_spi(_Altcraft) import AltcraftTarget
#endif
#if canImport(AltcraftCore)
@testable import AltcraftCore
#endif
#if canImport(AltcraftPush)
@testable import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@testable import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@testable import AltcraftTarget
#endif

/// In-memory Core Data stack for isolated tests.
public final class TestCoreDataStack {

    /// Stack persistence mode.
    public enum Mode {
        /// Standalone in-memory container fully isolated per test (default).
        case inMemory(modelName: String? = nil, bundleToken: AnyClass, bundleIdentifier: String? = nil)
        /// Proxy to SDK's real container (CoreDataManager.shared.persistentContainer).
        case sdkPersistent
        /// Proxy to a specific SDK module container (e.g. `pushDatabase.persistentContainer`).
        case sdkManager(NSPersistentContainer?)
    }

    public let container: NSPersistentContainer
    public let viewContext: NSManagedObjectContext

    /// Primary initializer selecting a mode.
    public init(mode: Mode) {
        switch mode {
        case let .inMemory(modelName, bundleToken, bundleIdentifier):
            let bundle: Bundle = {
                if let id = bundleIdentifier, let b = Bundle(identifier: id) {
                    return b
                }
                return Bundle(for: bundleToken)
            }()

            let model: NSManagedObjectModel = {
                if let name = modelName,
                   let url = bundle.url(forResource: name, withExtension: "momd"),
                   let m = NSManagedObjectModel(contentsOf: url) {
                    return m
                }
                if let merged = NSManagedObjectModel.mergedModel(from: [bundle]) {
                    return merged
                }
                fatalError("Core Data model not found in framework bundle")
            }()

            let c = NSPersistentContainer(name: modelName ?? "InMemory", managedObjectModel: model)

            // The SDK model is split into one configuration per module, so the
            // in-memory mirror needs one store per configuration (entities are
            // routed to their configuration's store, exactly like production).
            var loadError: Error?
            let configurations = model.configurations.isEmpty ? [nil] : model.configurations.map(Optional.some)
            c.persistentStoreDescriptions = configurations.map { configuration in
                let desc = NSPersistentStoreDescription()
                desc.type = NSInMemoryStoreType
                desc.configuration = configuration
                desc.shouldAddStoreAsynchronously = false
                return desc
            }

            c.loadPersistentStores { _, error in loadError = error }
            if let error = loadError { fatalError("Failed to load in-memory store: \(error)") }

            c.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            c.viewContext.automaticallyMergesChangesFromParent = true

            self.container = c
            self.viewContext = c.viewContext

        case .sdkPersistent:
            let coreContainer = CoreDataManager.shared.persistentContainer
            coreContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            coreContainer.viewContext.automaticallyMergesChangesFromParent = true

            self.container = coreContainer
            self.viewContext = coreContainer.viewContext

        case .sdkManager(let managerContainer):
            let c = managerContainer ?? CoreDataManager.shared.persistentContainer
            c.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            c.viewContext.automaticallyMergesChangesFromParent = true

            self.container = c
            self.viewContext = c.viewContext
        }
    }
    /// Convenience factory mirroring previous signature for minimal diffs.
    public convenience init(modelName: String? = nil, bundleToken: AnyClass, bundleIdentifier: String? = nil) {
        self.init(mode: .inMemory(modelName: modelName, bundleToken: bundleToken, bundleIdentifier: bundleIdentifier))
    }

    /// Returns the SDK module container whose model defines `entityName`.
    ///
    /// Because the SDK now runs one Core Data container per module, an entity
    /// only exists in the container of its owning module. This routes an
    /// entity name to that container (Core first for the core entities).
    public static func sdkContainer(containingEntity entityName: String) -> NSPersistentContainer? {
        let moduleManagers: [CoreDataManager] = [
            CoreDataManager.shared,
            pushDatabase,
            profileDatabase,
            inAppDatabase,
            targetDatabase
        ]
        return moduleManagers.first {
            $0.persistentContainer.managedObjectModel.entitiesByName[entityName] != nil
        }?.persistentContainer
    }

    /// Returns a configured background context on the SDK module container
    /// that defines `entityName`, or nil if no module model knows the entity.
    public static func sdkBackgroundContext(containingEntity entityName: String) -> NSManagedObjectContext? {
        guard let container = sdkContainer(containingEntity: entityName) else { return nil }
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.undoManager = nil
        return context
    }

    /// Registers the optional module lifecycle workers so SDK events
    /// (r-token change, clear) reach per-module cleanup.
    ///
    /// Production code registers modules during SDK initialization
    /// (`Init` → `ModuleRegistry.applyModuleConfigurations`); tests call
    /// this helper directly.
    public static func registerPurgeModules() async {
        await ModuleRegistry.shared.register(PushModuleLifecycle.shared)
        await ModuleRegistry.shared.register(TargetModuleLifecycle.shared)
        await ModuleRegistry.shared.register(InAppModuleLifecycle.shared)
        await ModuleRegistry.shared.register(ProfileModuleLifecycle.shared)
    }

    /// Removes the module lifecycle workers registered by
    /// ``registerPurgeModules()``.
    public static func unregisterPurgeModules() async {
        await ModuleRegistry.shared.unregister(PushConstants.Module.id)
        await ModuleRegistry.shared.unregister(TargetConstants.Module.id)
        await ModuleRegistry.shared.unregister(InAppConstants.Module.id)
        await ModuleRegistry.shared.unregister(ProfileConstants.Module.id)
    }

    public func newBGContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return ctx
    }

    /// Wipes in-memory store; no-op for sdkPersistent.
    public func wipe() {
        guard container.persistentStoreCoordinator.persistentStores.first?.type == NSInMemoryStoreType else { return }

        // Drop stale registered objects: the container (and its long-lived
        // viewContext) survives across tests, only the store is recreated.
        container.viewContext.reset()

        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }
        container.persistentStoreDescriptions = []
        let configurations = container.managedObjectModel.configurations.isEmpty
            ? [nil]
            : container.managedObjectModel.configurations.map(Optional.some)
        for configuration in configurations {
            do {
                try coordinator.addPersistentStore(
                    ofType: NSInMemoryStoreType,
                    configurationName: configuration,
                    at: nil,
                    options: nil
                )
            } catch {
                fatalError("Failed to recreate in-memory store: \(error)")
            }
        }
    }
}
