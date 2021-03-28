// swift-tools-version:5.1
import PackageDescription



let package = Package(
	name: "BSONSerialization",
	products: [
		.library(name: "BSONSerialization", targets: ["BSONSerialization"])
	],
	dependencies: [
		.package(url: "https://github.com/Frizlab/stream-reader.git", from: "3.0.0-rc")
	],
	targets: [
		.target(name: "BSONSerialization", dependencies: ["StreamReader"]),
		.testTarget(name: "BSONSerializationTests", dependencies: ["BSONSerialization"])
	]
)
