// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProdNoteShared",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ProdNoteShared", targets: ["ProdNoteShared"])
    ],
    targets: [
        .target(name: "ProdNoteShared")
    ]
)
