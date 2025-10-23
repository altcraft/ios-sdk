// swift-tools-version:5.10
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
            path: "Altcraft",
            resources: [
                .process("dataBase/DataBase.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "AltcraftTests",
            dependencies: ["Altcraft"],
            path: "AltcraftTests"
        )
    ]
)
