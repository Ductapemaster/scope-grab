// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ScopeGrab",
    platforms: [.macOS(.v14)],
    targets: [
        // Scope protocol and filename logic, kept free of UI so it can be unit-tested.
        .target(name: "ScopeGrabCore"),
        .executableTarget(name: "ScopeGrab", dependencies: ["ScopeGrabCore"]),
        .testTarget(name: "ScopeGrabCoreTests", dependencies: ["ScopeGrabCore"]),
    ]
)
