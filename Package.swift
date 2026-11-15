// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Calc3D",
    defaultLocalization: "pt",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Calc3D", targets: ["Calc3D"]),
        .library(name: "Calc3DCore", targets: ["Calc3DCore"]),
    ],
    targets: [
        // Regras de negócio puras (sem UI), reutilizáveis e testáveis.
        .target(name: "Calc3DCore"),
        // Aplicativo macOS em SwiftUI.
        .executableTarget(
            name: "Calc3D",
            dependencies: ["Calc3DCore"]
        ),
        .testTarget(
            name: "Calc3DCoreTests",
            dependencies: ["Calc3DCore"]
        ),
    ]
)
