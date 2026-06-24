// swift-tools-version: 6.0
import PackageDescription

// AlarmCore is the *pure* heart of the app: data value-types + the scheduling
// engine. It has ZERO dependency on SwiftUI, SwiftData, AlarmKit or
// UserNotifications, so it compiles and is unit-tested on plain macOS with
// `swift test`. The iOS app links it and maps its SwiftData @Model onto these
// value types before handing them to the calculator.
let package = Package(
    name: "AlarmCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AlarmCore", targets: ["AlarmCore"])
    ],
    targets: [
        .target(name: "AlarmCore"),
        .testTarget(name: "AlarmCoreTests", dependencies: ["AlarmCore"])
    ]
)
