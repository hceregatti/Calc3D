import Foundation

struct ImportedFilament: Sendable, Equatable {
    let type: String?
    let colorHex: String?
    let grams: Double
}

/// Estimativas de uma mesa gravadas pelo fatiador.
struct ImportedPlate: Sendable, Identifiable {
    let index: Int
    let weightGrams: Double?
    let durationSeconds: Double?
    let filaments: [ImportedFilament]
    var id: Int { index }
}

struct ImportedModelData: Sendable {
    let name: String
    let weightGrams: Double?
    let durationSeconds: Double?
    /// Todas as mesas fatiadas do arquivo (vazio em STL ou 3MF sem fatiamento).
    var plates: [ImportedPlate] = []
    /// Peso estimado pelo volume da malha (só quando o arquivo não traz o peso do fatiador). Aproximação.
    var estimatedWeight: WeightEstimate? = nil

    /// Mesmos dados, usando só a mesa escolhida.
    func selecting(_ plate: ImportedPlate) -> ImportedModelData {
        ImportedModelData(name: name, weightGrams: plate.weightGrams, durationSeconds: plate.durationSeconds, plates: plates,
                          estimatedWeight: estimatedWeight)
    }
}

enum ModelFileImportError: LocalizedError {
    case unsupportedFormat
    case invalidSTL
    case invalid3MF
    case metadataTooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            "Escolha um arquivo STL ou 3MF."
        case .invalidSTL:
            "O arquivo STL está vazio ou inválido."
        case .invalid3MF:
            "Não foi possível ler este arquivo 3MF."
        case .metadataTooLarge:
            "Os metadados do arquivo 3MF são grandes demais para leitura."
        }
    }
}

/// Reads a model name and explicit slicing estimates without estimating from mesh geometry.
enum ModelFileImporter {
    private static let maxArchiveListingBytes = 2 * 1024 * 1024
    private static let maxSliceInfoBytes = 1024 * 1024

    static func importFile(at url: URL) throws -> ImportedModelData {
        let name = url.deletingPathExtension().lastPathComponent
        switch url.pathExtension.lowercased() {
        case "stl":
            try validateSTL(at: url)
            var data = ImportedModelData(name: name, weightGrams: nil, durationSeconds: nil)
            if let metrics = ModelVolumeEstimator.metricsForSTL(at: url),
               let grams = ModelVolumeEstimator.estimateWeight(metrics: metrics, settings: EstimationSettings()) {
                data.estimatedWeight = WeightEstimate(grams: grams, pieces: 1)
            }
            return data
        case "3mf":
            return try import3MF(at: url, name: name)
        default:
            throw ModelFileImportError.unsupportedFormat
        }
    }

    private static func validateSTL(at url: URL) throws {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard !data.isEmpty else { throw ModelFileImportError.invalidSTL }

        if let text = String(data: data, encoding: .utf8),
           text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("solid"),
           text.lowercased().contains("facet") {
            return
        }

        guard data.count >= 84 else { throw ModelFileImportError.invalidSTL }
        let triangleCount = data[80..<84].enumerated().reduce(UInt32(0)) { value, pair in
            value | (UInt32(pair.element) << (UInt32(pair.offset) * 8))
        }
        let expectedSize = 84 + Int(triangleCount) * 50
        guard triangleCount > 0, expectedSize == data.count else {
            throw ModelFileImportError.invalidSTL
        }
    }

    private static func import3MF(at url: URL, name: String) throws -> ImportedModelData {
        var data = try readSliceInfo(at: url, name: name)
        let hasWeight = data.weightGrams != nil || data.plates.contains { $0.weightGrams != nil }
        if !hasWeight, let entries = try? archiveEntries(at: url) {
            let settingsData = entries.first { $0.caseInsensitiveCompare("Metadata/project_settings.config") == .orderedSame }
                .flatMap { try? runUnzip(["-p", url.path, $0], maxBytes: 8 * 1024 * 1024) }
            let settings = settingsData.map(ModelVolumeEstimator.settings(from:)) ?? EstimationSettings()
            if let (metrics, pieces) = ModelVolumeEstimator.metricsFor3MF(at: url, entries: entries),
               let grams = ModelVolumeEstimator.estimateWeight(metrics: metrics, settings: settings) {
                data.estimatedWeight = WeightEstimate(grams: grams, pieces: pieces)
            }
        }
        return data
    }

    private static func archiveEntries(at url: URL) throws -> [String] {
        let listing = try runUnzip(["-Z1", url.path], maxBytes: maxArchiveListingBytes)
        guard let paths = String(data: listing, encoding: .utf8) else { throw ModelFileImportError.invalid3MF }
        return paths.split(whereSeparator: \.isNewline).map(String.init)
    }

    private static func readSliceInfo(at url: URL, name: String) throws -> ImportedModelData {
        let listing = try runUnzip(["-Z1", url.path], maxBytes: maxArchiveListingBytes)
        guard let paths = String(data: listing, encoding: .utf8) else {
            throw ModelFileImportError.invalid3MF
        }
        let entries = paths.split(whereSeparator: \.isNewline).map(String.init)
        guard entries.contains(where: { $0.caseInsensitiveCompare("3D/3dmodel.model") == .orderedSame }) else {
            throw ModelFileImportError.invalid3MF
        }
        guard let sliceInfoPath = entries.first(where: {
            $0.caseInsensitiveCompare("Metadata/slice_info.config") == .orderedSame
        }) else {
            return ImportedModelData(name: name, weightGrams: nil, durationSeconds: nil)
        }

        let sliceInfo = try runUnzip(["-p", url.path, sliceInfoPath], maxBytes: maxSliceInfoBytes)
        let parser = SliceInfoParser()
        let xml = XMLParser(data: sliceInfo)
        xml.delegate = parser
        guard xml.parse() else { throw ModelFileImportError.invalid3MF }

        let estimatedPlates = parser.plates.filter { ($0.prediction ?? 0) > 0 }
        let plates = estimatedPlates.enumerated().map { offset, plate in
            let weight = plate.filamentWeights.values.reduce(0, +)
            return ImportedPlate(
                index: plate.index ?? offset + 1,
                weightGrams: weight > 0 ? weight : nil,
                durationSeconds: plate.prediction,
                filaments: plate.filaments
            )
        }
        // Com mais de uma mesa fatiada não dá para saber qual vale; a escolha fica com quem usa.
        guard plates.count == 1, let plate = plates.first else {
            return ImportedModelData(name: name, weightGrams: nil, durationSeconds: nil, plates: plates)
        }
        return ImportedModelData(name: name, weightGrams: plate.weightGrams, durationSeconds: plate.durationSeconds, plates: plates)
    }

    static func runUnzip(_ arguments: [String], maxBytes: Int) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()

        var data = Data()
        do {
            while let chunk = try output.fileHandleForReading.read(upToCount: 64 * 1024), !chunk.isEmpty {
                data.append(chunk)
                guard data.count <= maxBytes else {
                    process.terminate()
                    throw ModelFileImportError.metadataTooLarge
                }
            }
        } catch {
            if process.isRunning { process.terminate() }
            throw error
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ModelFileImportError.invalid3MF }
        return data
    }
}

private struct ParsedPlate {
    var index: Int?
    var prediction: Double?
    var filaments: [ImportedFilament] = []
    var filamentWeights: [String: Double] = [:]
}

private final class SliceInfoParser: NSObject, XMLParserDelegate {
    private(set) var plates: [ParsedPlate] = []
    private var currentPlateIndex: Int?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String]
    ) {
        switch elementName.lowercased() {
        case "plate":
            plates.append(ParsedPlate())
            currentPlateIndex = plates.indices.last
        case "metadata":
            guard let index = currentPlateIndex else { return }
            switch attributes["key"]?.lowercased() {
            case "prediction":
                if let value = decimal(attributes["value"]), value > 0 { plates[index].prediction = value }
            case "index":
                plates[index].index = attributes["value"].flatMap { Int($0) }
            default:
                break
            }
        case "filament":
            guard let index = currentPlateIndex,
                  let id = attributes["id"],
                  let weight = decimal(attributes["used_g"]), weight > 0 else { return }
            plates[index].filamentWeights[id] = weight
            let type = attributes["type"].flatMap { $0.isEmpty ? nil : $0 }
            let color = attributes["color"].flatMap { $0.isEmpty ? nil : $0 }
            plates[index].filaments.append(ImportedFilament(type: type, colorHex: color, grams: weight))
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName.lowercased() == "plate" { currentPlateIndex = nil }
    }

    private func decimal(_ text: String?) -> Double? {
        guard let text, let value = Double(text), value.isFinite else { return nil }
        return value
    }
}
