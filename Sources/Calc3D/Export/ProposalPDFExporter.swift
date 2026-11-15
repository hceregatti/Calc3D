import AppKit
import Calc3DCore
import CoreText
import Foundation

/// Renderiza uma proposta comercial em PDF vetorial com paginação automática.
enum ProposalPDFExporter {
    enum ExportError: LocalizedError {
        case noItems
        case invalidItem
        case cannotCreatePDF

        var errorDescription: String? {
            switch self {
            case .noItems: "Adicione ao menos um produto antes de exportar o PDF."
            case .invalidItem: "Revise as quantidades e os preços dos produtos desta proposta."
            case .cannotCreatePDF: "Não foi possível criar o arquivo PDF neste local."
            }
        }
    }

    static func write(_ proposal: ProposalRecord, to url: URL) throws {
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

        let layout = PDFLayout(context: context, proposal: proposal, pageSize: mediaBox.size)
        layout.startPage()
        for item in proposal.items {
            layout.draw(item)
        }
        layout.drawTotal(total: total)
        layout.finish()
        let pdfData = output as Data
        try pdfData.write(to: url, options: .atomic)
    }
}

private final class PDFLayout {
    private let primaryInk = CGColor(gray: 0.08, alpha: 1)
    private let secondaryInk = CGColor(gray: 0.42, alpha: 1)
    private let context: CGContext
    private let proposal: ProposalRecord
    private let pageSize: CGSize
    private let margin: CGFloat = 48
    private var cursorY: CGFloat = 0
    private var pageNumber = 0

    init(context: CGContext, proposal: ProposalRecord, pageSize: CGSize) {
        self.context = context
        self.proposal = proposal
        self.pageSize = pageSize
    }

    func startPage() {
        pageNumber += 1
        context.beginPDFPage(nil)
        cursorY = pageSize.height - margin

        drawText("PROPOSTA COMERCIAL", x: margin, y: cursorY - 22, font: font(size: 10, weight: .bold), color: secondaryInk)
        drawText("\(pageNumber)", x: pageSize.width - margin - 18, y: cursorY - 20, font: font(size: 10), color: secondaryInk)
        cursorY -= 44

        if pageNumber == 1 {
            _ = drawParagraph(cleanTitle, x: margin, width: pageSize.width - 2 * margin,
                              font: font(size: 22, weight: .bold), color: primaryInk, spacing: 10)
            drawText("Data: \(proposal.updatedAt.formatted(date: .long, time: .omitted))", x: margin, y: cursorY - 13, font: font(size: 10), color: secondaryInk)
            cursorY -= 23

            if !proposal.customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = drawParagraph("Cliente: \(proposal.customerName)", x: margin, width: pageSize.width - 2 * margin,
                                  font: font(size: 11, weight: .medium), color: primaryInk, spacing: 4)
            }
            if !proposal.customerContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = drawParagraph("Contato: \(proposal.customerContact)", x: margin, width: pageSize.width - 2 * margin,
                                  font: font(size: 10), color: secondaryInk, spacing: 4)
            }
            cursorY -= 10
        } else {
            drawText(cleanTitle, x: margin, y: cursorY - 18, font: font(size: 15, weight: .bold), color: primaryInk)
            cursorY -= 32
        }

        drawTableHeader()
    }

    func draw(_ item: ProposalItem) {
        guard let subtotal = item.subtotal else { return }
        ensureSpace(54)
        _ = drawParagraph(item.name, x: margin, width: pageSize.width - 2 * margin,
                          font: font(size: 11, weight: .bold), color: primaryInk, spacing: 4)
        ensureSpace(30)
        let rowTop = cursorY

        drawText("\(item.quantity)", x: 340, y: rowTop - 12, font: font(size: 10), color: primaryInk)
        drawText(Currency.brl(item.unitPrice), x: 385, y: rowTop - 12, font: font(size: 10), color: primaryInk)
        drawText(Currency.brl(subtotal), x: 485, y: rowTop - 12, font: font(size: 10, weight: .medium), color: primaryInk)
        cursorY -= 20

        let details = item.details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !details.isEmpty {
            _ = drawParagraph(details, x: margin, width: pageSize.width - 2 * margin,
                              font: font(size: 9), color: secondaryInk, spacing: 3)
        }

        cursorY -= 10
        drawRule(at: cursorY)
        cursorY -= 12
    }

    func drawTotal(total: Double) {
        ensureSpace(54)
        cursorY -= 6
        drawText("TOTAL", x: margin, y: cursorY - 18, font: font(size: 12, weight: .bold), color: primaryInk)
        drawText(Currency.brl(total), x: pageSize.width - margin - 100, y: cursorY - 18,
                 font: font(size: 14, weight: .bold), color: primaryInk)
    }

    func finish() {
        context.endPDFPage()
        context.closePDF()
    }

    private var cleanTitle: String {
        let title = proposal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Orçamento" : title
    }

    private func drawTableHeader() {
        let y = cursorY - 12
        drawText("PRODUTO", x: margin, y: y, font: font(size: 9, weight: .bold), color: secondaryInk)
        drawText("QTD.", x: 340, y: y, font: font(size: 9, weight: .bold), color: secondaryInk)
        drawText("UNITÁRIO", x: 385, y: y, font: font(size: 9, weight: .bold), color: secondaryInk)
        drawText("SUBTOTAL", x: 485, y: y, font: font(size: 9, weight: .bold), color: secondaryInk)
        cursorY -= 21
        drawRule(at: cursorY)
        cursorY -= 14
    }

    private func ensureSpace(_ height: CGFloat) {
        if cursorY - height < margin {
            context.endPDFPage()
            startPage()
        }
    }

    @discardableResult
    private func drawParagraph(
        _ text: String,
        x: CGFloat,
        width: CGFloat,
        font: CTFont,
        color: CGColor,
        spacing: CGFloat
    ) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(string)
        var offset = 0
        var usedHeight: CGFloat = 0

        while offset < string.length {
            let available = cursorY - margin
            if available < 24 {
                context.endPDFPage()
                startPage()
                continue
            }

            let path = CGPath(rect: CGRect(x: x, y: margin, width: width, height: available), transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: offset, length: 0),
                path,
                nil
            )
            CTFrameDraw(frame, context)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else {
                context.endPDFPage()
                startPage()
                continue
            }

            let consumed = visible.location + visible.length - offset
            offset += consumed
            if offset < string.length {
                usedHeight += available
                context.endPDFPage()
                startPage()
            } else {
                var fitRange = CFRange()
                let fit = CTFramesetterSuggestFrameSizeWithConstraints(
                    framesetter,
                    CFRange(location: visible.location, length: visible.length),
                    nil,
                    CGSize(width: width, height: .greatestFiniteMagnitude),
                    &fitRange
                )
                let height = ceil(fit.height)
                cursorY -= height + spacing
                usedHeight += height + spacing
            }
        }

        return usedHeight
    }

    private func drawText(_ text: String, x: CGFloat, y: CGFloat, font: CTFont, color: CGColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    private func drawRule(at y: CGFloat) {
        context.saveGState()
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
        context.strokePath()
        context.restoreGState()
    }

    private func font(size: CGFloat, weight: NSFont.Weight = .regular) -> CTFont {
        let nsFont = NSFont.systemFont(ofSize: size, weight: weight)
        return CTFontCreateWithName(nsFont.fontName as CFString, size, nil)
    }
}
