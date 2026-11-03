// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "ReviewLabViews",
    platforms: [.iOS("26.0")],
    products: [.library(name: "ReviewLabViews", targets: ["ReviewLabViews"])],
    targets: [.target(name: "ReviewLabViews")]
)
