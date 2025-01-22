// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RealBatteryTester",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .application(
            name: "RealBatteryTester",
            targets: ["RealBatteryTester"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "RealBatteryTester",
            dependencies: [],
            path: "RealBatteryTester",
            sources: [
                "BatteryMonitor.swift",
                "BatteryStatusView.swift",
                RealBatteryTesterApp.swift",
                "ContentView.swift",
                "TestReportView.swift",
                "TestHistoryView.swift"
            ]
        ),
    ]
)
