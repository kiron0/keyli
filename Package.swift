// swift-tools-version: 5.9
import PackageDescription
import Foundation

let cltTestingFrameworkPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let needsCLTTestingSearchPath = FileManager.default.fileExists(
    atPath: cltTestingFrameworkPath + "/Testing.framework"
)

var testSwiftSettings: [SwiftSetting] = []
var testLinkerSettings: [LinkerSetting] = []

if needsCLTTestingSearchPath {
    testSwiftSettings = [
        .unsafeFlags(["-F", cltTestingFrameworkPath])
    ]
    testLinkerSettings = [
        .unsafeFlags([
            "-F", cltTestingFrameworkPath,
            "-framework", "Testing",
            "-Xlinker", "-rpath", "-Xlinker", cltTestingFrameworkPath,
            "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
        ])
    ]
}

let package = Package(
    name: "Keyli",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Keyli", targets: ["Keyli"]),
    ],
    targets: [
        .executableTarget(
            name: "Keyli",
            path: "Sources/Keyli"
        ),
        .testTarget(
            name: "KeyliTests",
            dependencies: ["Keyli"],
            path: "Tests/KeyliTests",
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        ),
    ]
)
