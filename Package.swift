// swift-tools-version: 5.10
//
//  Package.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.
//
//  Single-root SPM manifest for the modular Altcraft iOS SDK.
//  Consumers add either the full `Altcraft` product or any combination
//  of the individual module products (`AltcraftCore` is included
//  automatically as a dependency of the other modules).

import PackageDescription

let package = Package(
    name: "Altcraft",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "AltcraftCore", targets: ["AltcraftCore"]),
        .library(name: "AltcraftPush", targets: ["AltcraftPush"]),
        .library(name: "AltcraftProfile", targets: ["AltcraftProfile"]),
        .library(name: "AltcraftInApp", targets: ["AltcraftInApp"]),
        .library(name: "AltcraftTarget", targets: ["AltcraftTarget"]),
        .library(name: "Altcraft", targets: ["Altcraft"])
    ],
    targets: [
        .target(
            name: "AltcraftCore",
            path: "Altcraft/Core",
            resources: [
                .process("data/db/Core.xcdatamodeld"),
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "AltcraftPush",
            dependencies: ["AltcraftCore"],
            path: "Altcraft/Push",
            resources: [
                .process("data/db/Push.xcdatamodeld"),
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "AltcraftProfile",
            dependencies: ["AltcraftCore"],
            path: "Altcraft/Profile",
            resources: [
                .process("data/db/Profile.xcdatamodeld"),
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "AltcraftInApp",
            dependencies: ["AltcraftCore"],
            path: "Altcraft/InApp",
            resources: [
                .process("data/db/InApp.xcdatamodeld"),
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "AltcraftTarget",
            dependencies: ["AltcraftCore"],
            path: "Altcraft/Target",
            resources: [
                .process("data/db/Target.xcdatamodeld"),
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "Altcraft",
            dependencies: [
                "AltcraftCore",
                "AltcraftPush",
                "AltcraftProfile",
                "AltcraftInApp",
                "AltcraftTarget"
            ],
            path: "Altcraft",
            exclude: [
                "Core",
                "Push",
                "Profile",
                "InApp",
                "Target",
                "Altcraft.docc"
            ],
            resources: [
                .copy("Altcraft.h")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
