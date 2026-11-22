import Foundation

/// Volume (mm³) e área de superfície (mm²) de uma malha.
struct MeshMetrics: Sendable {
    var volume: Double = 0
    var area: Double = 0

    static func + (a: MeshMetrics, b: MeshMetrics) -> MeshMetrics {
        MeshMetrics(volume: a.volume + b.volume, area: a.area + b.area)
    }

    /// Aplica uma transformação 3MF (12 números) ou escala uniforme: volume pelo determinante, área por det^(2/3).
    func scaled(volumeFactor: Double) -> MeshMetrics {
        MeshMetrics(volume: volume * volumeFactor, area: area * pow(volumeFactor, 2.0 / 3.0))
    }
}

/// Parâmetros do fatiador que influenciam o peso (lidos do projeto quando existem).
struct EstimationSettings: Sendable {
    var densityGramsPerCm3 = 1.24
    var infillFraction = 0.15
    var wallThicknessMM = 0.9
}

struct WeightEstimate: Sendable, Equatable {
    let grams: Double
    let pieces: Int
}

/// Estima o peso de um modelo pelo volume. É uma aproximação: casca (paredes + topo/base) maciça mais
/// o miolo com a densidade de preenchimento; ignora suportes, brim, torre de limpeza e desperdício.
enum ModelVolumeEstimator {
    private static let maxModelBytes = 300 * 1024 * 1024

    static func estimateWeight(metrics: MeshMetrics, settings: EstimationSettings) -> Double? {
        guard metrics.volume > 0 else { return nil }
        let shell = min(metrics.volume, metrics.area * settings.wallThicknessMM)
        let inner = metrics.volume - shell
        let solidMM3 = shell + inner * settings.infillFraction
        let grams = solidMM3 / 1000 * settings.densityGramsPerCm3
        return grams.isFinite && grams > 0 ? grams : nil
    }

    // MARK: STL

    static func metricsForSTL(at url: URL) -> MeshMetrics? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]), data.count <= maxModelBytes else { return nil }
        var acc = Accumulator()
        if data.count >= 84 {
            let count = Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 80, as: UInt32.self) }.littleEndian)
            if count > 0, 84 + count * 50 == data.count {
                data.withUnsafeBytes { raw in
                    for i in 0..<count {
                        let base = 84 + i * 50 + 12
                        func v(_ k: Int) -> SIMD3<Double> {
                            let o = base + k * 12
                            return SIMD3(Double(Float(bitPattern: raw.loadUnaligned(fromByteOffset: o, as: UInt32.self).littleEndian)),
                                         Double(Float(bitPattern: raw.loadUnaligned(fromByteOffset: o + 4, as: UInt32.self).littleEndian)),
                                         Double(Float(bitPattern: raw.loadUnaligned(fromByteOffset: o + 8, as: UInt32.self).littleEndian)))
                        }
                        acc.add(v(0), v(1), v(2))
                    }
                }
                return acc.metrics
            }
        }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var vertices: [SIMD3<Double>] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count == 4, parts[0].lowercased() == "vertex",
                  let x = Double(parts[1]), let y = Double(parts[2]), let z = Double(parts[3]) else { continue }
            vertices.append(SIMD3(x, y, z))
            if vertices.count == 3 { acc.add(vertices[0], vertices[1], vertices[2]); vertices.removeAll(keepingCapacity: true) }
        }
        return acc.metrics
    }

    // MARK: 3MF

    /// Soma o volume de todos os itens da cesta (build) do 3MF, aplicando as transformações; nil se não achar malha.
    static func metricsFor3MF(at url: URL, entries: [String]) -> (MeshMetrics, pieces: Int)? {
        let modelPaths = entries.filter { $0.lowercased().hasSuffix(".model") }
        guard let mainPath = modelPaths.first(where: { $0.caseInsensitiveCompare("3D/3dmodel.model") == .orderedSame }) else { return nil }
        var files: [String: ModelFile] = [:]
        for path in modelPaths {
            guard let data = try? ModelFileImporter.runUnzip(["-p", url.path, path], maxBytes: maxModelBytes) else { continue }
            let parser = ModelXMLParser()
            let xml = XMLParser(data: data)
            xml.delegate = parser
            guard xml.parse() else { continue }
            files["/" + path] = parser.file
        }
        guard let main = files["/" + mainPath], !main.items.isEmpty else { return nil }
        let unitFactor = main.unitScale
        var total = MeshMetrics()
        var pieces = 0
        for item in main.items {
            guard let m = resolve(objectID: item.objectID, in: "/" + mainPath, files: files, depth: 0) else { continue }
            total = total + m.scaled(volumeFactor: item.volumeFactor)
            pieces += 1
        }
        guard total.volume > 0 else { return nil }
        // Unidades: o volume escala com o cubo.
        total = total.scaled(volumeFactor: pow(unitFactor, 3))
        return (total, pieces)
    }

    private static func resolve(objectID: Int, in path: String, files: [String: ModelFile], depth: Int) -> MeshMetrics? {
        guard depth < 8, let object = files[path]?.objects[objectID] else { return nil }
        if let mesh = object.mesh { return mesh }
        var sum = MeshMetrics()
        var found = false
        for component in object.components {
            let target = component.path ?? path
            if let m = resolve(objectID: component.objectID, in: target, files: files, depth: depth + 1) {
                sum = sum + m.scaled(volumeFactor: component.volumeFactor)
                found = true
            }
        }
        return found ? sum : nil
    }

    // MARK: Impressora do projeto

    /// Impressora, bico, camada e perfil gravados em project_settings.config (Bambu Studio, Orca, Creality Print).
    static func printer(from projectSettings: Data) -> ImportedPrinter? {
        guard let json = try? JSONSerialization.jsonObject(with: projectSettings) as? [String: Any] else { return nil }
        func text(_ key: String) -> String? {
            let value: String?
            if let s = json[key] as? String { value = s } else if let list = json[key] as? [Any], let s = list.first as? String { value = s } else { value = nil }
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed?.isEmpty ?? true) ? nil : trimmed
        }
        return ImportedPrinter(
            model: text("printer_model"), profile: text("printer_settings_id"),
            nozzleDiameter: text("nozzle_diameter"), layerHeight: text("layer_height"),
            printProfile: text("print_settings_id")
        )
    }

    // MARK: Parâmetros do projeto

    /// Densidade, preenchimento e paredes gravados em Metadata/project_settings.config (Bambu/Orca/Prusa).
    static func settings(from projectSettings: Data) -> EstimationSettings {
        var settings = EstimationSettings()
        guard let json = try? JSONSerialization.jsonObject(with: projectSettings) as? [String: Any] else { return settings }
        func number(_ value: Any?) -> Double? {
            if let s = value as? String { return Double(s.trimmingCharacters(in: CharacterSet(charactersIn: "% "))) }
            if let n = value as? Double { return n }
            return nil
        }
        if let list = json["filament_density"] as? [Any], let d = number(list.first), d > 0.5, d < 5 { settings.densityGramsPerCm3 = d }
        if let infill = number(json["sparse_infill_density"]), infill >= 0, infill <= 100 { settings.infillFraction = infill / 100 }
        if let loops = number(json["wall_loops"]), loops >= 1, loops <= 20 { settings.wallThicknessMM = max(0.8, loops * 0.45) }
        return settings
    }
}

// MARK: - Geometria

private struct Accumulator {
    var volume = 0.0
    var area = 0.0

    mutating func add(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>) {
        let cross = simd_cross(b, c)
        volume += (a.x * cross.x + a.y * cross.y + a.z * cross.z) / 6
        let n = simd_cross(b - a, c - a)
        area += 0.5 * (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
    }

    var metrics: MeshMetrics { MeshMetrics(volume: abs(volume), area: area) }
}

private func simd_cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
    SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}

// MARK: - XML do 3MF

private struct Component {
    let objectID: Int
    let path: String?
    let volumeFactor: Double
}

private struct ModelObject {
    var mesh: MeshMetrics?
    var components: [Component] = []
}

private struct BuildItem {
    let objectID: Int
    let volumeFactor: Double
}

private struct ModelFile {
    var unitScale = 1.0
    var objects: [Int: ModelObject] = [:]
    var items: [BuildItem] = []
}

private final class ModelXMLParser: NSObject, XMLParserDelegate {
    private(set) var file = ModelFile()
    private var currentID: Int?
    private var currentIsModel = true
    private var currentObject = ModelObject()
    private var vertices: [SIMD3<Double>] = []
    private var acc = Accumulator()
    private var inMesh = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes a: [String: String]) {
        switch elementName {
        case "model":
            switch a["unit"]?.lowercased() {
            case "micron": file.unitScale = 0.001
            case "centimeter": file.unitScale = 10
            case "meter": file.unitScale = 1000
            case "inch": file.unitScale = 25.4
            case "foot": file.unitScale = 304.8
            default: file.unitScale = 1
            }
        case "object":
            currentID = a["id"].flatMap { Int($0) }
            currentIsModel = (a["type"] ?? "model") == "model"
            currentObject = ModelObject()
        case "mesh":
            inMesh = true
            vertices.removeAll(keepingCapacity: true)
            acc = Accumulator()
        case "vertex" where inMesh:
            if let x = a["x"].flatMap(Double.init), let y = a["y"].flatMap(Double.init), let z = a["z"].flatMap(Double.init) {
                vertices.append(SIMD3(x, y, z))
            } else {
                vertices.append(.zero)
            }
        case "triangle" where inMesh:
            guard let i = a["v1"].flatMap({ Int($0) }), let j = a["v2"].flatMap({ Int($0) }), let k = a["v3"].flatMap({ Int($0) }),
                  vertices.indices.contains(i), vertices.indices.contains(j), vertices.indices.contains(k) else { return }
            acc.add(vertices[i], vertices[j], vertices[k])
        case "component":
            guard let id = a["objectid"].flatMap({ Int($0) }) else { return }
            currentObject.components.append(Component(objectID: id, path: a["p:path"], volumeFactor: Self.volumeFactor(a["transform"])))
        case "item":
            guard let id = a["objectid"].flatMap({ Int($0) }) else { return }
            file.items.append(BuildItem(objectID: id, volumeFactor: Self.volumeFactor(a["transform"])))
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "mesh":
            inMesh = false
            currentObject.mesh = acc.metrics
            vertices.removeAll()
        case "object":
            if let id = currentID, currentIsModel { file.objects[id] = currentObject }
            currentID = nil
        default:
            break
        }
    }

    /// |determinante| da parte linear da transformação (12 números; identidade se ausente).
    private static func volumeFactor(_ text: String?) -> Double {
        guard let text else { return 1 }
        let m = text.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        guard m.count >= 9 else { return 1 }
        let det = m[0] * (m[4] * m[8] - m[5] * m[7]) - m[1] * (m[3] * m[8] - m[5] * m[6]) + m[2] * (m[3] * m[7] - m[4] * m[6])
        return abs(det)
    }
}
