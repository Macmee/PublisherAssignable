// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "Assignable",
  platforms: [
    .macOS(.v10_14), .iOS(.v13), .tvOS(.v13), .watchOS(.v5)
  ],
  products: [
  .library(
    name: "Assignable",
    targets: ["Assignable"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Assignable",
      dependencies: [],
      path: "Sources/Assignable")
  ]
)
