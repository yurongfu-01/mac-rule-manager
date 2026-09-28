// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacRuleManager",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacRuleManager", targets: ["RuleManager"]),
        .executable(name: "RuleCoreChecks", targets: ["RuleCoreChecks"]),
        .library(name: "RuleCore", targets: ["RuleCore"])
    ],
    targets: [
        .target(name: "RuleCore"),
        .executableTarget(name: "RuleManager", dependencies: ["RuleCore"]),
        .executableTarget(name: "RuleCoreChecks", dependencies: ["RuleCore"]),
        .testTarget(name: "RuleCoreTests", dependencies: ["RuleCore"])
    ]
)
