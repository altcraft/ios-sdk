//
//  TestCoreDataStack.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  © 2025 Altcraft. All rights reserved.
//

import CoreData
@testable import Altcraft

public final class TestCoreDataStack {

    public enum Mode {
        /// Standalone in-memory container fully isolated per test (default).
        case inMemory(modelName: String? = nil, bundleToken: AnyClass, bundleIdentifier: String? = nil)
        /// Proxy to SDK's real container (CoreDataManager.shared.persistentContainer).
        case sdkPersistent
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
            let desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
            desc.shouldAddStoreAsynchronously = false
            c.persistentStoreDescriptions = [desc]

            var loadError: Error?
            c.loadPersistentStores { _, error in loadError = error }
            if let error = loadError { fatalError("Failed to load in-memory store: \(error)") }

            c.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            c.viewContext.automaticallyMergesChangesFromParent = true

            self.container = c
            self.viewContext = c.viewContext

        case .sdkPersistent:
            let c = CoreDataManager.shared.persistentContainer
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

    public func newBGContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return ctx
    }

    /// Wipes in-memory store; no-op for sdkPersistent.
    public func wipe() {
        guard container.persistentStoreCoordinator.persistentStores.first?.type == NSInMemoryStoreType else { return }

        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]
        do {
            try coordinator.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: nil
            )
        } catch {
            fatalError("Failed to recreate in-memory store: \(error)")
        }
    }
}
