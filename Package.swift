// swift-tools-version:5.9
import PackageDescription

let package = Package(
	name: "64kDemo",
	platforms: [
		.macOS("12.0")
	],
	products: [
		.executable(name: "64kDemo", targets: ["64kDemo"])
	],
	targets: [
		.executableTarget(
			name: "64kDemo",
			resources: [
				.copy("../../Shaders.metallib")
			]
		)
	]
)
