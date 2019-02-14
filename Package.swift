// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PerfectNIOCompat",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "PerfectNIOCompat",
            targets: ["PerfectNIOCompat",
					  "PerfectHTTPC",
					  "PerfectHTTPServerC",
					  "PerfectMustacheC",
					  "PerfectWebSocketsC"]),
    ],
    dependencies: [
		.package(url: "https://github.com/PerfectlySoft/Perfect-NIO.git", .branch("master")),
		.package(url: "https://github.com/PerfectlySoft/Perfect-Mustache.git", .branch("4.0-dev")),
		.package(url: "https://github.com/PerfectlySoft/PerfectLib.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "PerfectNIOCompat",
            dependencies: ["PerfectNIO",
						   "PerfectHTTPServerC",
						   "PerfectHTTPC",
						   "PerfectMustacheC",
						   "PerfectWebSocketsC"]),
		.target(
			name: "PerfectHTTPC",
			dependencies: ["PerfectLib", "PerfectNIO"]),
		.target(
			name: "PerfectHTTPServerC",
			dependencies: ["PerfectHTTPC", "PerfectNIO", "PerfectLib"]),
		.target(
			name: "PerfectMustacheC",
			dependencies: ["PerfectMustache",
						   "PerfectHTTPC"]),
		.target(
			name: "PerfectWebSocketsC",
			dependencies: ["PerfectHTTPC", "PerfectHTTPServerC"]),
        .testTarget(
            name: "PerfectNIOCompatTests",
            dependencies: ["PerfectNIOCompat"]),
    ]
)
