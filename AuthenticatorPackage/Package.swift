// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AuthenticatorPackage",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AuthenticatorPackage",
            targets: [
                .utils,
            ]
        ),
    ],
    targets: [
        .target(name: .utils),
    ]
)

extension Target.Dependency {
    static var utils: Self { .byName(name: .utils) }
}

extension String {
    static var utils: Self { "Utils" }
}
