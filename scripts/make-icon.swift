// Gera o ícone do app (AppIcon.icns) desenhado em código.
// Uso: swift scripts/make-icon.swift <diretório de saída>
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build")
let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Fundo arredondado com gradiente.
    let inset = s * 0.09
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let bg = NSBezierPath(roundedRect: rect, xRadius: s * 0.2, yRadius: s * 0.2)
    NSGradient(colors: [NSColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 1),
                        NSColor(red: 0.42, green: 0.25, blue: 0.85, alpha: 1)])!
        .draw(in: bg, angle: -90)

    // Camadas de impressão (barras empilhadas).
    NSColor.white.withAlphaComponent(0.95).setFill()
    let layerH = s * 0.065
    let widths: [CGFloat] = [0.50, 0.42, 0.34, 0.26]
    for (i, w) in widths.enumerated() {
        let y = s * 0.24 + CGFloat(i) * layerH * 1.45
        let width = s * w
        NSBezierPath(roundedRect: NSRect(x: (s - width) / 2, y: y, width: width, height: layerH),
                     xRadius: layerH / 2, yRadius: layerH / 2).fill()
    }

    // Bico extrusor.
    let nozzle = NSBezierPath()
    nozzle.move(to: NSPoint(x: s * 0.42, y: s * 0.78))
    nozzle.line(to: NSPoint(x: s * 0.58, y: s * 0.78))
    nozzle.line(to: NSPoint(x: s * 0.52, y: s * 0.66))
    nozzle.line(to: NSPoint(x: s * 0.48, y: s * 0.66))
    nozzle.close()
    NSColor(red: 1, green: 0.75, blue: 0.2, alpha: 1).setFill()
    nozzle.fill()

    // Símbolo R$.
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: s * 0.13, weight: .heavy),
        .foregroundColor: NSColor(red: 1, green: 0.75, blue: 0.2, alpha: 1),
    ]
    let text = NSAttributedString(string: "R$", attributes: attrs)
    let ts = text.size()
    text.draw(at: NSPoint(x: s * 0.73 - ts.width / 2, y: s * 0.62))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
print(iconset.path)
