// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "RxPaginationFeedback",
    products: [
        .library(
            name: "RxPaginationFeedback",
            targets: ["RxPaginationFeedback"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "5.0.0"),
        .package(url: "https://github.com/NoTests/RxFeedback.swift.git", .upToNextMajor(from: "3.0.0"))
    ],
    targets: [
        .target(
            name: "RxPaginationFeedback",
            dependencies: ["RxFeedback"]),
        .testTarget(
            name: "RxPaginationFeedbackTests",
            dependencies: ["RxPaginationFeedback", "RxFeedback", "RxSwift", "RxCocoa", "RxTest"]),
    ]
)
