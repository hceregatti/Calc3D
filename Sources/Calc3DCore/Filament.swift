import Foundation

/// Tipos de filamento com valores típicos de impressão (referência; cada marca varia).
public enum FilamentMaterial: String, CaseIterable, Codable, Sendable, Identifiable {
    case pla = "PLA"
    case plaPlus = "PLA+"
    case petg = "PETG"
    case abs = "ABS"
    case asa = "ASA"
    case tpu = "TPU"
    case nylon = "Nylon (PA)"
    case pc = "PC"
    case pva = "PVA"
    case other = "Outro"

    public var id: String { rawValue }

    /// Temperatura de bico (mín–máx, °C), mesa (°C) e densidade (g/cm³) típicas.
    public var typicalProfile: (nozzleMin: Double, nozzleMax: Double, bed: Double, density: Double) {
        switch self {
        case .pla: (190, 220, 60, 1.24)
        case .plaPlus: (200, 230, 60, 1.24)
        case .petg: (220, 250, 80, 1.27)
        case .abs: (230, 260, 100, 1.04)
        case .asa: (240, 270, 100, 1.07)
        case .tpu: (210, 240, 50, 1.21)
        case .nylon: (250, 285, 80, 1.14)
        case .pc: (260, 300, 110, 1.20)
        case .pva: (190, 210, 60, 1.23)
        case .other: (200, 230, 60, 1.24)
        }
    }
}

/// Um rolo de filamento da biblioteca.
public struct Filament: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var brand: String = ""
    /// Linha/nome do produto (ex.: "Silk", "Basic").
    public var name: String = ""
    public var material: FilamentMaterial = .pla
    public var colorName: String = ""
    /// Cor para exibição, no formato "#RRGGBB".
    public var colorHex: String = "#9A9994"
    /// Diâmetro do fio (mm).
    public var diameter: Double = 1.75
    /// Peso líquido do rolo (g).
    public var netWeight: Double = 1000
    /// Quanto resta no rolo (g).
    public var remainingWeight: Double = 1000
    /// Preço pago pelo rolo.
    public var price: Double = 0
    public var nozzleTempMin: Double = 190
    public var nozzleTempMax: Double = 220
    public var bedTemp: Double = 60
    /// Densidade (g/cm³).
    public var density: Double = 1.24
    /// Link de compra deste filamento.
    public var purchaseURL: String = ""
    public var store: String = ""
    public var notes: String = ""
    public var createdAt: Date = .now

    public init() {}

    /// Novo filamento já com os valores típicos do material.
    public init(material: FilamentMaterial) {
        self.material = material
        applyTypicalProfile()
    }

    public mutating func applyTypicalProfile() {
        let p = material.typicalProfile
        nozzleTempMin = p.nozzleMin
        nozzleTempMax = p.nozzleMax
        bedTemp = p.bed
        density = p.density
    }

    /// Decodifica campo a campo para que novas propriedades não invalidem dados salvos.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        let d = Filament()
        id = value(.id, d.id)
        brand = value(.brand, d.brand)
        name = value(.name, d.name)
        material = value(.material, d.material)
        colorName = value(.colorName, d.colorName)
        colorHex = value(.colorHex, d.colorHex)
        diameter = value(.diameter, d.diameter)
        netWeight = value(.netWeight, d.netWeight)
        remainingWeight = value(.remainingWeight, d.remainingWeight)
        price = value(.price, d.price)
        nozzleTempMin = value(.nozzleTempMin, d.nozzleTempMin)
        nozzleTempMax = value(.nozzleTempMax, d.nozzleTempMax)
        bedTemp = value(.bedTemp, d.bedTemp)
        density = value(.density, d.density)
        purchaseURL = value(.purchaseURL, d.purchaseURL)
        store = value(.store, d.store)
        notes = value(.notes, d.notes)
        createdAt = value(.createdAt, d.createdAt)
    }

    // MARK: Derivados

    /// Preço por grama (R$/g).
    public var pricePerGram: Double {
        Sanitize.nonNegative(price) / Sanitize.atLeastOne(netWeight)
    }

    /// Fração restante do rolo (0…1).
    public var remainingFraction: Double {
        min(Sanitize.nonNegative(remainingWeight) / Sanitize.atLeastOne(netWeight), 1)
    }

    /// Nome para listas: "Marca Linha Material · Cor".
    public var displayName: String {
        let title = [brand, name, material.rawValue]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let color = colorName.trimmingCharacters(in: .whitespaces)
        return color.isEmpty ? title : "\(title) · \(color)"
    }

    /// Link de compra válido (somente http/https).
    public var purchaseLink: URL? {
        var text = purchaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased()),
              url.host?.contains(".") == true
        else { return nil }
        return url
    }

    /// Pesquisa de compra na web (Google Shopping) para este filamento.
    public var searchURL: URL? {
        var terms = ["filamento", brand, name, material.rawValue, colorName]
        terms.append(String(format: "%.2fmm", diameter).replacingOccurrences(of: ".", with: ",").replacingOccurrences(of: "0mm", with: "mm"))
        let weight = netWeight >= 1000 && netWeight.truncatingRemainder(dividingBy: 1000) == 0
            ? "\(Int(netWeight / 1000))kg" : "\(Int(netWeight))g"
        terms.append(weight)
        let query = terms.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "tbm", value: "shop")]
        return components?.url
    }
}
