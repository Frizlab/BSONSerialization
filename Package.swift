// swift-tools-version:4.2
import PackageDescription



let package = Package(
	name: "BSONSerialization",
	products: [
		.library(name: "BSONSerialization", targets: ["BSONSerialization"])
	],
	dependencies: [
		.package(url: "https://github.com/Frizlab/SimpleStream", from: "2.0.0"),
	],
	targets: [
		.target(name: "BSONSerialization", dependencies: ["SimpleStream"]),
		.testTarget(name: "BSONSerializationTests", dependencies: ["BSONSerialization"])
	]
)
