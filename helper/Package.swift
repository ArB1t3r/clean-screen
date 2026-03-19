// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "CleanScreenHelper",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .executable(name: "CleanScreenHelper", targets: ["CleanScreenHelper"]),
  ],
  targets: [
    .executableTarget(
      name: "CleanScreenHelper",
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("SwiftUI"),
        .linkedFramework("Quartz"),
        .linkedFramework("Carbon"),
      ]
    ),
  ]
)
