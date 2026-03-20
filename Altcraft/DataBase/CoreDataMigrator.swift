//
//  CoreDataMigrator.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

enum HeavyMigrationError: Error {
    case modelNotFound(String)
    case storeNotFound(URL)
    case sourceModelResolveFailed
    case mappingModelNotFound(from: String, to: String)
}

struct ModelStep {
    public let name: String
    public let url: URL
    public let model: NSManagedObjectModel
}

/// Handles step-based Core Data migrations inside the SDK.
final class CoreDataMigrator: @unchecked Sendable {

    static let shared = CoreDataMigrator()
    private init() {}

    /// Performs migration if the store is not compatible with the current model.
    /// Should be called before initializing `CoreDataManager.shared`.
    @discardableResult
    func migrateStore(modelName: String,
                      storeURL: URL,
                      allowInferredMappingAsFallback: Bool = false,
                      bundles: [Bundle] = CoreDataMigrator.defaultBundles()
    ) throws -> Bool {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { throw HeavyMigrationError.storeNotFound(storeURL) }
        guard let destinationModel = CoreDataMigrator.loadCurrentModel(named: modelName, bundles: bundles) else {
            throw HeavyMigrationError.modelNotFound(modelName)
        }
        
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil)
        if destinationModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
            return false
        }
        
        let chain = try CoreDataMigrator.buildModelChain(named: modelName, bundles: bundles)
        guard let startIndex = chain.firstIndex(where: { $0.model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) }) else {
            throw HeavyMigrationError.sourceModelResolveFailed
        }
        
        let currentStoreURL = storeURL
        for i in stride(from: startIndex, to: chain.count - 1, by: 1) {
            let fromStep = chain[i]
            let toStep   = chain[i + 1]
            try migrate(storeURL: currentStoreURL,
                        from: fromStep.model,
                        to: toStep.model,
                        mappingNameHint: "\(fromStep.name)_to_\(toStep.name)",
                        allowInferredMappingAsFallback: allowInferredMappingAsFallback,
                        in: bundles)
        }
        return true
    }

    /// Migrates the store from one model version to another.
    private func migrate(storeURL: URL,
                                from sourceModel: NSManagedObjectModel,
                                to destinationModel: NSManagedObjectModel,
                                mappingNameHint: String,
                                allowInferredMappingAsFallback: Bool,
                                in bundles: [Bundle]) throws {
        let customMapping = CoreDataMigrator.loadCustomMappingModel(named: mappingNameHint, bundles: bundles)
        let mappingModel: NSMappingModel = try {
            if let m = customMapping { return m }
            if allowInferredMappingAsFallback {
                return try NSMappingModel.inferredMappingModel(forSourceModel: sourceModel, destinationModel: destinationModel)
            }
            let fromName = CoreDataMigrator.name(for: sourceModel) ?? "unknown_from"
            let toName   = CoreDataMigrator.name(for: destinationModel) ?? "unknown_to"
            throw HeavyMigrationError.mappingModelNotFound(from: fromName, to: toName)
        }()

        let fm = FileManager.default
        let tempURL = storeURL.deletingLastPathComponent().appendingPathComponent(storeURL.lastPathComponent + ".migrating")
        try? fm.removeItem(at: tempURL)

        let mgr = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        try mgr.migrateStore(from: storeURL,
                             sourceType: NSSQLiteStoreType,
                             options: nil,
                             with: mappingModel,
                             toDestinationURL: tempURL,
                             destinationType: NSSQLiteStoreType,
                             destinationOptions: nil)

        let wal = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let shm = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        try? fm.removeItem(at: wal)
        try? fm.removeItem(at: shm)
        if fm.fileExists(atPath: storeURL.path) { try fm.removeItem(at: storeURL) }
        try fm.moveItem(at: tempURL, to: storeURL)
    }

    /// Returns a list of candidate bundles containing Core Data models.
    static func defaultBundles() -> [Bundle] {
        var arr: [Bundle] = []
        let frameworkBundle = Bundle(for: CoreDataMigrator.self)
        if let urlInFramework = frameworkBundle.url(forResource: "AltcraftResources", withExtension: "bundle"),
           let resInFramework = Bundle(url: urlInFramework) {
            arr.append(resInFramework)
        }
        if let urlInMain = Bundle.main.url(forResource: "AltcraftResources", withExtension: "bundle"),
           let resInMain = Bundle(url: urlInMain) {
            arr.append(resInMain)
        }
        #if SWIFT_PACKAGE
        arr.append(Bundle.module)
        #endif
        arr.append(frameworkBundle)
        arr.append(Bundle.main)
        return arr
    }

    /// Loads the current (Set Current Version) model from .momd.
    static func loadCurrentModel(named: String, bundles: [Bundle]) -> NSManagedObjectModel? {
        for b in bundles {
            if let url = b.url(forResource: named, withExtension: "momd"),
               let m = NSManagedObjectModel(contentsOf: url) { return m }
            if let url = b.url(forResource: named, withExtension: "mom"),
               let m = NSManagedObjectModel(contentsOf: url) { return m }
        }
        return nil
    }

    /// Builds an ordered chain of model versions found in the .momd bundle.
    private static func buildModelChain(named: String, bundles: [Bundle]) throws -> [ModelStep] {
        var steps: [ModelStep] = []
        for b in bundles {
            if let momdURL = b.url(forResource: named, withExtension: "momd"),
               let contents = try? FileManager.default.contentsOfDirectory(
                at: momdURL, includingPropertiesForKeys: nil
               ) {
                for url in contents where url.pathExtension == "mom" {
                    if let m = NSManagedObjectModel(contentsOf: url) {
                        let name = url.deletingPathExtension().lastPathComponent
                        steps.append(ModelStep(name: name, url: url, model: m))
                    }
                }
            } else if let momURL = b.url(forResource: named, withExtension: "mom"),
                      let m = NSManagedObjectModel(contentsOf: momURL) {
                let name = momURL.deletingPathExtension().lastPathComponent
                steps.append(ModelStep(name: name, url: momURL, model: m))
            }
        }
        steps.sort { $0.name < $1.name }
        return steps
    }

    /// Loads a custom .cdm mapping model by name.
    private static func loadCustomMappingModel(named: String, bundles: [Bundle]) -> NSMappingModel? {
        for b in bundles {
            if let url = b.url(forResource: named, withExtension: "cdm"),
               let mapping = NSMappingModel(contentsOf: url) {
                return mapping
            }
        }
        return nil
    }

    /// Returns a readable name for the given Core Data model.
    private static func name(for model: NSManagedObjectModel) -> String? {
        return model.entitiesByName.isEmpty ? nil : model.entitiesByName.keys.sorted().first
    }
}
