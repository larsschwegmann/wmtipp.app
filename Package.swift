// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "WMTipp-Server",
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/vapor/auth.git", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/vapor/leaf.git", .upToNextMajor(from: "3.0.0")),
        // 🔵 Swift ORM (queries, models, relations, etc) built on SQLite 3.
        //.package(url: "https://github.com/vapor/fluent-sqlite.git", from: "3.0.0-rc.2"),
        //.package(url: "https://github.com/vapor/fluent-mysql.git", from: "3.0.0-rc"),
        .package(url: "https://github.com/vapor/fluent-postgresql.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/vapor/redis.git", .upToNextMajor(from: "3.0.0")),
        //Alamofire + Moya for interacting with OpenLigaDB
        //.package(url: "https://github.com/larsschwegmann/Alamofire.git", .branch("linux")),
        //.package(url: "https://github.com/Moya/Moya.git", .upToNextMajor(from: "11.0.0"))
        .package(url: "https://github.com/rymcol/SwiftCron.git", from: "0.2.0")
    ],
    targets: [
        .target(name: "App", dependencies: ["FluentPostgreSQL", "Redis", "Vapor", "Authentication", "Leaf"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"]),
        .target(name: "Scheduler", dependencies: ["SwiftCron"])
    ]
)

