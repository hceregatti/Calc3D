import AppKit
import Calc3DCore
import CoreText
import Foundation

/// Renderiza um orçamento personalizado em PDF vetorial com paginação automática.
@MainActor
enum ProposalPDFExporter {
    enum ExportError: LocalizedError {
        case noItems
        case invalidItem
        case cannotCreatePDF

        var errorDescription: String? {
            switch self {
            case .noItems: "Adicione ao menos um produto antes de exportar o PDF."
            case .invalidItem: "Revise as quantidades e os preços dos produtos deste orçamento."
            case .cannotCreatePDF: "Não foi possível criar o arquivo PDF neste local."
            }
        }
    }

    static func write(_ proposal: ProposalRecord, profile: CompanyProfile, images: ImageStore, to url: URL) throws {
        guard !proposal.items.isEmpty else { throw ExportError.noItems }
        guard proposal.items.allSatisfy({
            $0.quantity > 0 && $0.quantity <= ProposalItem.maxQuantity && $0.unitPrice.isFinite
                && $0.unitPrice >= 0 && $0.subtotal?.isFinite == true
        }) else { throw ExportError.invalidItem }
        guard let total = proposal.total, total.isFinite else { throw ExportError.invalidItem }

        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        let output = NSMutableData()
        guard
            let consumer = CGDataConsumer(data: output as CFMutableData),
            let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            throw ExportError.cannotCreatePDF
        }

        let layout = PDFLayout(context: context, proposal: proposal, profile: profile, images: images, pageSize: mediaBox.size)
        layout.startPage()
        for item in proposal.items {
            layout.draw(item)
        }
        layout.drawTotals(total: total)
        layout.drawConditions()
        layout.finish()
        try (output as Data).write(to: url, options: .atomic)
    }
}

@MainActor
private final class PDFLayout {
    private let primaryInk = CGColor(gray: 0.1, alpha: 1)
    private let secondaryInk = CGColor(gray: 0.42, alpha: 1)
    private let ruleColor = CGColor(gray: 0.86, alpha: 1)
    private let accent: CGColor
    private let context: CGContext
    private let proposal: ProposalRecord
    private let profile: CompanyProfile
    private let images: ImageStore
    private let pageSize: CGSize
    private let margin: CGFloat = 40
    /// Limite inferior do conteúdo; abaixo dele fica o rodapé.
    private var bottomLimit: CGFloat { margin + 14 }
    private var contentWidth: CGFloat { pageSize.width - 2 * margin }
    private var right: CGFloat { pageSize.width - margin }
    private var cursorY: CGFloat = 0
    private var pageNumber = 0
    private var showsTableHeader = true

    // Colunas da tabela
    private let photoSize: CGFloat = 54
    private var showsPhotos: Bool { profile.showProductPhotos }
    private var textX: CGFloat { showsPhotos ? margin + 8 + photoSize + 12 : margin + 8 }
    private var textWidth: CGFloat { 330 - textX }
    private var qtyRight: CGFloat { 380 }
    private var unitRight: CGFloat { 462 }
    private var subtotalRight: CGFloat { right - 8 }

    init(context: CGContext, proposal: ProposalRecord, profile: CompanyProfile, images: ImageStore, pageSize: CGSize) {
        self.context = context
        self.proposal = proposal
        self.profile = profile
        self.images = images
        self.pageSize = pageSize
        self.accent = (NSColor(hex: profile.accentHex) ?? .systemBlue).cgColor
    }

    // MARK: Páginas

    func startPage() {
        pageNumber += 1
        context.beginPDFPage(nil)
        fill(CGRect(x: 0, y: pageSize.height - 6, width: pageSize.width, height: 6), color: accent)
        cursorY = pageSize.height - margin

        if pageNumber == 1 {
            drawCompanyHeader()
            drawDocumentHeader()
            drawCustomer()
        } else {
            drawCompactHeader()
        }
        drawFooter()
        if showsTableHeader { drawTableHeader() }
    }

    func finish() {
        context.endPDFPage()
        context.closePDF()
    }

    private func newPage() {
        context.endPDFPage()
        startPage()
    }

    private func ensureSpace(_ height: CGFloat) {
        let pageCapacity = pageSize.height - 2 * margin - 120
        if cursorY - min(height, pageCapacity) < bottomLimit { newPage() }
    }

    // MARK: Cabeçalho

    private func drawCompanyHeader() {
        let top = cursorY
        var logoHeight: CGFloat = 0
        var logoWidth: CGFloat = 0
        if let logo = images.image(for: profile.logoImageID), logo.size.width > 0, logo.size.height > 0 {
            let box = CGSize(width: 170, height: 70)
            let scale = min(box.width / logo.size.width, box.height / logo.size.height)
            let size = CGSize(width: logo.size.width * scale, height: logo.size.height * scale)
            drawImage(logo, in: CGRect(x: margin, y: top - size.height, width: size.width, height: size.height))
            logoHeight = size.height
            logoWidth = size.width
        }

        let infoMaxWidth = contentWidth - (logoWidth > 0 ? logoWidth + 20 : 0)
        var lines: [(String, CTFont, CGColor)] = []
        let name = profile.companyName.trimmed
        if !name.isEmpty { lines.append((name, font(14, .bold), primaryInk)) }
        if !profile.document.trimmed.isEmpty { lines.append((profile.document.trimmed, font(9), secondaryInk)) }
        for line in profile.address.split(whereSeparator: \.isNewline) where !line.trimmed.isEmpty {
            lines.append((line.trimmed, font(9), secondaryInk))
        }
        let phones = [profile.phone, profile.whatsapp.trimmed.isEmpty ? "" : "WhatsApp \(profile.whatsapp.trimmed)"]
        for row in [phones, [profile.email, profile.website], [profile.instagram]] {
            let text = row.map(\.trimmed).filter { !$0.isEmpty }.joined(separator: "  ·  ")
            if !text.isEmpty { lines.append((text, font(9), secondaryInk)) }
        }

        // Sem logo e com nome, o nome fica à esquerda em destaque.
        var y = top
        if logoWidth == 0, let first = lines.first, !name.isEmpty {
            drawText(first.0, x: margin, y: y - 16, font: font(18, .bold), color: accent, maxWidth: contentWidth * 0.5)
            lines.removeFirst()
            logoHeight = 24
        }
        for (index, line) in lines.enumerated() {
            let lineHeight: CGFloat = index == 0 && line.0 == name ? 18 : 12.5
            y -= lineHeight
            drawTextRight(line.0, right: right, y: y + 3, font: line.1, color: line.2, maxWidth: infoMaxWidth)
        }

        let used = max(logoHeight, top - y)
        if used > 0 {
            cursorY = top - used - 14
            stroke(at: cursorY, color: accent, width: 1)
            cursorY -= 22
        }
    }

    private func drawDocumentHeader() {
        var label = "ORÇAMENTO"
        if let number = proposal.formattedNumber { label += "  Nº \(number)" }
        drawText(label, x: margin, y: cursorY - 10, font: font(10, .bold), color: accent)
        drawTextRight("Emissão: \(longDate(proposal.updatedAt))",
                      right: right, y: cursorY - 10, font: font(9), color: secondaryInk)
        cursorY -= 18

        drawParagraph(cleanTitle, x: margin, width: contentWidth * 0.68, font: font(20, .bold), color: primaryInk, spacing: 4)
        if let validUntil = proposal.validUntil {
            drawTextRight("Válido até \(validUntil.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: Currency.locale))) (\(proposal.validityDays) dias)",
                          right: right, y: cursorY + 6, font: font(9, .medium), color: secondaryInk)
        }
        cursorY -= 10
    }

    private func drawCustomer() {
        let fields: [(String, String)] = [
            ("Cliente", proposal.customerName),
            ("CPF/CNPJ", proposal.customerDocument),
            ("Contato", proposal.customerContact),
            ("Endereço", proposal.customerAddress),
        ].map { ($0.0, $0.1.trimmed) }.filter { !$0.1.isEmpty }
        guard !fields.isEmpty else { return }

        let valueX = margin + 74
        let valueWidth = contentWidth - 86
        let heights = fields.map { measure($0.1, font: font(10, $0.0 == "Cliente" ? .semibold : .regular), width: valueWidth) }
        let boxHeight = heights.reduce(0) { $0 + $1 + 4 } + 30

        let box = CGRect(x: margin, y: cursorY - boxHeight, width: contentWidth, height: boxHeight)
        fill(box, color: accent.copy(alpha: 0.07) ?? ruleColor, radius: 6)
        drawText("PARA", x: margin + 12, y: cursorY - 15, font: font(8, .bold), color: accent)
        cursorY -= 22
        for (field, _) in zip(fields, heights) {
            drawText(field.0, x: margin + 12, y: cursorY - 10, font: font(9), color: secondaryInk)
            drawParagraph(field.1, x: valueX, width: valueWidth,
                          font: font(10, field.0 == "Cliente" ? .semibold : .regular), color: primaryInk, spacing: 4)
        }
        cursorY = box.minY - 18
    }

    private func drawCompactHeader() {
        let name = profile.companyName.trimmed
        drawText(name.isEmpty ? "ORÇAMENTO" : name, x: margin, y: cursorY - 12, font: font(10, .bold), color: primaryInk,
                 maxWidth: contentWidth * 0.55)
        var label = "Orçamento"
        if let number = proposal.formattedNumber { label += " Nº \(number)" }
        drawTextRight("\(label) · \(cleanTitle)", right: right, y: cursorY - 12, font: font(9), color: secondaryInk,
                      maxWidth: contentWidth * 0.4)
        cursorY -= 22
        stroke(at: cursorY, color: ruleColor, width: 0.5)
        cursorY -= 14
    }

    private func drawFooter() {
        stroke(at: margin, color: ruleColor, width: 0.5)
        let footer = profile.footerText.trimmed
        let fallback = [profile.companyName, profile.phone, profile.email].map(\.trimmed).filter { !$0.isEmpty }
            .joined(separator: "  ·  ")
        drawText(footer.isEmpty ? fallback : footer, x: margin, y: margin - 14, font: font(8), color: secondaryInk,
                 maxWidth: contentWidth - 70)
        drawTextRight("Página \(pageNumber)", right: right, y: margin - 14, font: font(8), color: secondaryInk)
    }

    // MARK: Itens

    private func drawTableHeader() {
        let height: CGFloat = 22
        fill(CGRect(x: margin, y: cursorY - height, width: contentWidth, height: height), color: accent, radius: 4)
        let y = cursorY - 14.5
        let white = CGColor(gray: 1, alpha: 1)
        drawText("PRODUTO", x: showsPhotos ? margin + 8 : textX, y: y, font: font(8, .bold), color: white)
        drawTextRight("QTD.", right: qtyRight, y: y, font: font(8, .bold), color: white)
        drawTextRight("UNITÁRIO", right: unitRight, y: y, font: font(8, .bold), color: white)
        drawTextRight("SUBTOTAL", right: subtotalRight, y: y, font: font(8, .bold), color: white)
        cursorY -= height + 4
    }

    func draw(_ item: ProposalItem) {
        guard let subtotal = item.subtotal else { return }
        let details = item.details.trimmed
        let nameFont = font(11, .semibold)
        let detailsFont = font(9)
        let textHeight = measure(item.name, font: nameFont, width: textWidth)
            + (details.isEmpty ? 0 : measure(details, font: detailsFont, width: textWidth) + 3)
        let rowHeight = max(showsPhotos ? photoSize : 0, textHeight) + 16
        ensureSpace(rowHeight)

        let page = pageNumber
        let top = cursorY - 8
        if showsPhotos {
            drawProductPhoto(item.imageID, in: CGRect(x: margin + 8, y: top - photoSize, width: photoSize, height: photoSize))
        }
        let numbersY = top - 12
        drawTextRight("\(item.quantity)", right: qtyRight, y: numbersY, font: font(10), color: primaryInk)
        drawTextRight(Currency.brl(item.unitPrice), right: unitRight, y: numbersY, font: font(10), color: primaryInk)
        drawTextRight(Currency.brl(subtotal), right: subtotalRight, y: numbersY, font: font(10, .semibold), color: primaryInk)

        cursorY = top
        drawParagraph(item.name.trimmed.isEmpty ? "Item sem nome" : item.name, x: textX, width: textWidth,
                      font: nameFont, color: primaryInk, spacing: 3)
        if !details.isEmpty {
            drawParagraph(details, x: textX, width: textWidth, font: detailsFont, color: secondaryInk, spacing: 0)
        }
        if showsPhotos && page == pageNumber {
            cursorY = min(cursorY, top - photoSize)
        }
        cursorY -= 8
        stroke(at: cursorY, color: ruleColor, width: 0.5)
    }

    private func drawProductPhoto(_ id: UUID?, in rect: CGRect) {
        let path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        if let image = images.image(for: id), image.size.width > 0, image.size.height > 0 {
            // Preenche o quadro mantendo a proporção (corta o excesso).
            let scale = max(rect.width / image.size.width, rect.height / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let target = CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
            context.saveGState()
            context.addPath(path)
            context.clip()
            drawImage(image, in: target)
            context.restoreGState()
        } else {
            // Imagem padrão de produto.
            context.saveGState()
            context.addPath(path)
            context.setFillColor(CGColor(gray: 0.94, alpha: 1))
            context.fillPath()
            context.restoreGState()
            let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
                .applying(.init(hierarchicalColor: NSColor(white: 0.62, alpha: 1)))
            if let symbol = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let size = symbol.size
                drawImage(symbol, in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                                             width: size.width, height: size.height))
            }
        }
        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(ruleColor)
        context.setLineWidth(0.5)
        context.strokePath()
        context.restoreGState()
    }

    // MARK: Totais e condições

    func drawTotals(total: Double) {
        showsTableHeader = false
        var rows: [(String, String)] = []
        let hasAdjustments = proposal.discount > 0 || proposal.shipping > 0
        if hasAdjustments, let itemsTotal = proposal.itemsTotal {
            rows.append(("Subtotal", Currency.brl(itemsTotal)))
            if proposal.shipping > 0 { rows.append(("Frete", Currency.brl(proposal.shipping))) }
            if proposal.discount > 0 { rows.append(("Desconto", "− " + Currency.brl(proposal.discount))) }
        }
        ensureSpace(CGFloat(rows.count) * 16 + 50)
        cursorY -= 10
        let labelRight = right - 130
        for row in rows {
            drawTextRight(row.0, right: labelRight, y: cursorY - 11, font: font(10), color: secondaryInk)
            drawTextRight(row.1, right: subtotalRight, y: cursorY - 11, font: font(10), color: primaryInk)
            cursorY -= 16
        }
        cursorY -= 4
        let box = CGRect(x: right - 230, y: cursorY - 32, width: 230, height: 32)
        fill(box, color: accent, radius: 6)
        let white = CGColor(gray: 1, alpha: 1)
        drawText("TOTAL", x: box.minX + 12, y: box.minY + 11, font: font(11, .bold), color: white)
        drawTextRight(Currency.brl(total), right: box.maxX - 12, y: box.minY + 10, font: font(15, .bold), color: white)
        cursorY = box.minY - 24
    }

    func drawConditions() {
        var sections: [(String, String)] = []
        if !proposal.paymentTerms.trimmed.isEmpty { sections.append(("Forma de pagamento", proposal.paymentTerms.trimmed)) }
        if !proposal.deliveryTime.trimmed.isEmpty { sections.append(("Prazo de entrega", proposal.deliveryTime.trimmed)) }
        if let validUntil = proposal.validUntil {
            sections.append(("Validade da proposta",
                             "\(proposal.validityDays) dias, até \(longDate(validUntil))."))
        }
        if !proposal.notes.trimmed.isEmpty { sections.append(("Observações", proposal.notes.trimmed)) }

        if !sections.isEmpty {
            ensureSpace(60)
            drawText("CONDIÇÕES", x: margin, y: cursorY - 10, font: font(9, .bold), color: accent)
            cursorY -= 16
            stroke(at: cursorY, color: ruleColor, width: 0.5)
            cursorY -= 10
            for section in sections {
                ensureSpace(34)
                drawText(section.0, x: margin, y: cursorY - 10, font: font(9, .semibold), color: primaryInk)
                cursorY -= 14
                drawParagraph(section.1, x: margin, width: contentWidth, font: font(9.5), color: secondaryInk, spacing: 10)
            }
        }

        let responsible = profile.responsibleName.trimmed
        if !responsible.isEmpty {
            ensureSpace(70)
            cursorY -= 34
            let lineWidth: CGFloat = 220
            let x = right - lineWidth
            context.saveGState()
            context.setStrokeColor(secondaryInk)
            context.setLineWidth(0.6)
            context.move(to: CGPoint(x: x, y: cursorY))
            context.addLine(to: CGPoint(x: right, y: cursorY))
            context.strokePath()
            context.restoreGState()
            drawCentered(responsible, centerX: x + lineWidth / 2, y: cursorY - 13, font: font(10, .semibold), color: primaryInk)
            let company = profile.companyName.trimmed
            if !company.isEmpty {
                drawCentered(company, centerX: x + lineWidth / 2, y: cursorY - 25, font: font(9), color: secondaryInk)
            }
            cursorY -= 30
        }
    }

    // MARK: Primitivas

    private func longDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: Currency.locale))
    }

    private var cleanTitle: String {
        let title = proposal.title.trimmed
        return title.isEmpty ? "Orçamento" : title
    }

    private func attributed(_ text: String, font: CTFont, color: CGColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ])
    }

    private func measure(_ text: String, font: CTFont, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let string = attributed(text, font: font, color: primaryInk)
        let framesetter = CTFramesetterCreateWithAttributedString(string)
        var fit = CFRange()
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(location: 0, length: string.length), nil,
            CGSize(width: width, height: .greatestFiniteMagnitude), &fit
        )
        return ceil(size.height)
    }

    private func drawParagraph(_ text: String, x: CGFloat, width: CGFloat, font: CTFont, color: CGColor, spacing: CGFloat) {
        guard !text.isEmpty else { return }
        let string = attributed(text, font: font, color: color)
        let framesetter = CTFramesetterCreateWithAttributedString(string)
        var offset = 0

        while offset < string.length {
            let available = cursorY - bottomLimit
            if available < 24 {
                newPage()
                continue
            }
            let path = CGPath(rect: CGRect(x: x, y: bottomLimit, width: width, height: available), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
            CTFrameDraw(frame, context)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else {
                newPage()
                continue
            }
            offset = visible.location + visible.length
            if offset < string.length {
                newPage()
            } else {
                var fitRange = CFRange()
                let fit = CTFramesetterSuggestFrameSizeWithConstraints(
                    framesetter, visible, nil, CGSize(width: width, height: .greatestFiniteMagnitude), &fitRange
                )
                cursorY -= ceil(fit.height) + spacing
            }
        }
    }

    private func line(_ text: String, font: CTFont, color: CGColor, maxWidth: CGFloat?) -> CTLine {
        let line = CTLineCreateWithAttributedString(attributed(text, font: font, color: color))
        guard let maxWidth, CTLineGetTypographicBounds(line, nil, nil, nil) > maxWidth,
              let truncated = CTLineCreateTruncatedLine(
                line, maxWidth, .end, CTLineCreateWithAttributedString(attributed("…", font: font, color: color))
              )
        else { return line }
        return truncated
    }

    private func drawText(_ text: String, x: CGFloat, y: CGFloat, font: CTFont, color: CGColor, maxWidth: CGFloat? = nil) {
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line(text, font: font, color: color, maxWidth: maxWidth), context)
    }

    private func drawTextRight(_ text: String, right: CGFloat, y: CGFloat, font: CTFont, color: CGColor, maxWidth: CGFloat? = nil) {
        let ctLine = line(text, font: font, color: color, maxWidth: maxWidth)
        let width = CTLineGetTypographicBounds(ctLine, nil, nil, nil)
        context.textPosition = CGPoint(x: right - width, y: y)
        CTLineDraw(ctLine, context)
    }

    private func drawCentered(_ text: String, centerX: CGFloat, y: CGFloat, font: CTFont, color: CGColor) {
        let ctLine = line(text, font: font, color: color, maxWidth: 260)
        let width = CTLineGetTypographicBounds(ctLine, nil, nil, nil)
        context.textPosition = CGPoint(x: centerX - width / 2, y: y)
        CTLineDraw(ctLine, context)
    }

    private func drawImage(_ image: NSImage, in rect: CGRect) {
        context.saveGState()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
    }

    private func fill(_ rect: CGRect, color: CGColor, radius: CGFloat = 0) {
        context.saveGState()
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.setFillColor(color)
        context.fillPath()
        context.restoreGState()
    }

    private func stroke(at y: CGFloat, color: CGColor, width: CGFloat) {
        context.saveGState()
        context.setStrokeColor(color)
        context.setLineWidth(width)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: right, y: y))
        context.strokePath()
        context.restoreGState()
    }

    private func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> CTFont {
        NSFont.systemFont(ofSize: size, weight: weight) as CTFont
    }
}

private extension StringProtocol {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
