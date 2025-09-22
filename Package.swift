//
//  Package.swift
//  
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import PackageDescription

let package = Package(
    name: "Altcraft",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Altcraft",
            targets: ["Altcraft"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Altcraft",
            path: "Altcraft"
        ),
        .testTarget(
            name: "AltcraftTests",
            dependencies: ["Altcraft"],
            path: "AltcraftTests"
        )
    ]
)
