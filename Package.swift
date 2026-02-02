// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DoDo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DoDo", targets: ["DoDo"])
    ],
    targets: [
        .executableTarget(
            name: "DoDo",
            path: "Sources/DoDo"
        )
    ]
)
