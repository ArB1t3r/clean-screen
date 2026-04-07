// swift-tools-version: 5.9

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
    .executableTarget(name: "CleanScreenHelper"),
  ]
)
