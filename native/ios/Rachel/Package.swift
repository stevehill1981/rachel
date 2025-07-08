// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Rachel",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Rachel",
            targets: ["Rachel"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/liveview-native/liveview-client-swiftui", from: "0.4.0-rc.1"),
    ],
    targets: [
        .target(
            name: "Rachel",
            dependencies: [
                .product(name: "LiveViewNative", package: "liveview-client-swiftui"),
                .product(name: "LiveViewNativeStylesheet", package: "liveview-client-swiftui"),
            ]
        ),
    ]
)