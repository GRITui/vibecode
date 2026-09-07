// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VibeCode",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "vibecode", targets: ["AIBot"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.9.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "LLMConfig",
            dependencies: [],
            path: "Sources/LLMConfig"
        ),
        .executableTarget(
            name: "AIBot",
            dependencies: ["TelegramBot", "OrbStack", "SelfHeal", "HealthMonitor", "WebServer", "LLMConfig"],
            path: "Sources/AIBot"
        ),
        .target(
            name: "TelegramBot",
            dependencies: [],
            path: "Sources/TelegramBot"
        ),
        .target(
            name: "OrbStack",
            dependencies: [],
            path: "Sources/OrbStack"
        ),
        .target(
            name: "SelfHeal",
            dependencies: ["OrbStack"],
            path: "Sources/SelfHeal"
        ),
        .target(
            name: "HealthMonitor",
            dependencies: ["OrbStack", "SelfHeal", "TelegramBot"],
            path: "Sources/HealthMonitor"
        ),
        .target(
            name: "WebServer",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                "OrbStack",
                "HealthMonitor",
                "TelegramBot",
                "LLMConfig"
            ],
            path: "Sources/WebServer"
        ),
        .testTarget(
            name: "VibeCodeTests",
            dependencies: [
                "AIBot", "TelegramBot", "OrbStack", "SelfHeal", "HealthMonitor", "WebServer", "LLMConfig",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests"
        )
    ]
)

