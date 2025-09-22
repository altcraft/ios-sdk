//
//  TestCoreDataStack.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import CoreData
@testable import Altcraft

public final class TestCoreDataStack {
    public let container: NSPersistentContainer
    public let viewContext: NSManagedObjectContext

    /// - Parameters:
    ///   - modelName: Optional .xcdatamodeld name (without extension). If nil, we fallback to merged model.
    ///   - bundleToken: Any class from the framework under test (used when bundleIdentifier is nil).
    ///   - bundleIdentifier: Optional bundle identifier of the framework (e.g., Constants.CoreData.identifier).
    public init(modelName: String? = nil, bundleToken: AnyClass, bundleIdentifier: String? = nil) {
        // Resolve the framework bundle: by identifier if provided, else by class token
        let bundle: Bundle = {
            if let id = bundleIdentifier, let b = Bundle(identifier: id) {
                return b
            }
            return Bundle(for: bundleToken)
        }()

        // Load model: try explicit .momd first, otherwise use merged model from the bundle
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

        // Create container with the resolved model
        container = NSPersistentContainer(name: modelName ?? "InMemory", managedObjectModel: model)

        // Use in-memory store for tests
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        desc.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [desc]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let error = loadError { fatalError("Failed to load in-memory store: \(error)") }

        viewContext = container.viewContext
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext.automaticallyMergesChangesFromParent = true
    }

    public func newBGContext() -> NSManagedObjectContext {
        // Background context for concurrent operations
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return ctx
    }

    public func wipe() {
        // Remove all stores and recreate a fresh in-memory store
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
