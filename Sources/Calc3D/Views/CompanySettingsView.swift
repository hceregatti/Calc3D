import Calc3DCore
import SwiftUI

/// Personalização do orçamento: logo, dados da empresa, contatos, aparência e padrões.
struct CompanySettingsView: View {
    @Environment(CalculatorViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let p = $model.companyProfile

        Form {
            Section {
                HStack {
                    Label(
                        model.companyHasUnsavedChanges ? "Alterações não salvas" : "Dados salvos",
                        systemImage: model.companyHasUnsavedChanges ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
                    )
                    .foregroundColor(model.companyHasUnsavedChanges ? Theme.warn : Theme.muted)
                    Spacer()
                    if let feedback = model.companyFeedback {
                        Text(feedback)
                            .font(.caption)
                            .foregroundStyle(feedback.hasSuffix("✔") ? Theme.success : Theme.danger)
                    }
                }
            } footer: {
                Text("Estes dados aparecem no cabeçalho, nas condições e no rodapé dos PDFs de orçamento.")
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack(alignment: .center, spacing: 16) {
                    ImageSlot(
                        image: model.imageStore.image(for: model.companyProfile.logoImageID),
                        width: 180, height: 90,
                        placeholderSymbol: "photo.badge.plus",
                        placeholderText: "Adicionar logo",
                        fit: .fit,
                        onChoose: { model.chooseCompanyLogo() },
                        onDropFile: { model.setCompanyLogo(from: $0) },
                        onRemove: { model.companyProfile.logoImageID = nil }
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PNG com fundo transparente fica melhor. A imagem é reduzida automaticamente.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Escolher logo…") { model.chooseCompanyLogo() }
                            if model.companyProfile.logoImageID != nil {
                                Button("Remover", role: .destructive) { model.companyProfile.logoImageID = nil }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                BadgeLabel("Logo", systemImage: "photo.fill", color: .pink)
            }

            Section {
                TextField("Nome da empresa", text: p.companyName, prompt: Text("Ex.: Studio 3D Print"))
                MaskedTextField(title: "CNPJ / CPF", text: p.document, prompt: "00.000.000/0001-00", mask: TextMask.cpfCnpj)
                TextField("Responsável (assinatura)", text: p.responsibleName, prompt: Text("Seu nome"))
            } header: {
                BadgeLabel("Empresa", systemImage: "building.2.fill", color: .indigo)
            }

            Section {
                MaskedTextField(title: "Telefone", text: p.phone, prompt: "(11) 3000-0000", mask: TextMask.phone)
                MaskedTextField(title: "WhatsApp", text: p.whatsapp, prompt: "(11) 90000-0000", mask: TextMask.phone)
                TextField("E-mail", text: p.email, prompt: Text("contato@empresa.com.br"))
                TextField("Site", text: p.website, prompt: Text("www.empresa.com.br"))
                TextField("Instagram", text: p.instagram, prompt: Text("@empresa"))
                TextField("Endereço", text: p.address, prompt: Text("Rua, número, bairro\nCidade – UF, CEP"), axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                BadgeLabel("Contato e endereço", systemImage: "phone.fill", color: .green)
            }

            Section {
                ColorPicker("Cor de destaque", selection: accentBinding, supportsOpacity: false)
                Toggle("Mostrar fotos dos produtos no PDF", isOn: p.showProductPhotos)
                TextField("Rodapé", text: p.footerText, prompt: Text("Obrigado pela preferência!"))
            } header: {
                BadgeLabel("Aparência do PDF", systemImage: "paintpalette.fill", color: .purple)
            } footer: {
                Text("Produtos sem foto usam uma imagem padrão.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Próximo número") {
                    TextField("Próximo número", value: p.nextProposalNumber, format: .number.grouping(.never))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 96)
                }
                Stepper(value: p.defaultValidityDays, in: 0...365) {
                    LabeledContent("Validade", value: model.companyProfile.defaultValidityDays == 0
                                   ? "Sem validade" : "\(model.companyProfile.defaultValidityDays) dias")
                }
                TextField("Forma de pagamento", text: p.defaultPaymentTerms, axis: .vertical)
                    .lineLimit(1...4)
                TextField("Prazo de entrega", text: p.defaultDeliveryTime, axis: .vertical)
                    .lineLimit(1...3)
                TextField("Observações", text: p.defaultNotes, prompt: Text("Ex.: cores podem variar levemente"), axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                BadgeLabel("Padrões para novos orçamentos", systemImage: "doc.badge.gearshape.fill", color: .orange)
            } footer: {
                Text("A numeração é atribuída ao salvar um orçamento pela primeira vez. Condições podem ser ajustadas em cada orçamento.")
                    .foregroundStyle(.secondary)
            }
        }
        .themedForm()
        .navigationTitle("Personalizar orçamento")
        .onChange(of: model.companyProfile.nextProposalNumber) { _, value in
            if value < 1 { model.companyProfile.nextProposalNumber = 1 }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    model.saveCompanyProfile()
                } label: {
                    Label("Salvar", systemImage: "checkmark.circle.fill")
                }
                .disabled(!model.companyHasUnsavedChanges)
                .help("Salva os dados da empresa e os padrões do orçamento")
            }
            ToolbarItem {
                Button {
                    model.previewSampleProposalPDF()
                } label: {
                    Label("Pré-visualizar PDF", systemImage: "eye.fill")
                }
                .help("Gera um orçamento de exemplo com estes dados e abre no Preview")
            }
            ToolbarItem {
                Button {
                    model.resetCompanyDefaults()
                } label: {
                    Label("Restaurar condições padrão", systemImage: "arrow.counterclockwise.circle.fill")
                }
                .help("Volta pagamento, prazo, validade, observações e rodapé aos textos sugeridos")
            }
        }
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: model.companyProfile.accentHex) ?? .systemBlue) },
            set: { model.companyProfile.accentHex = NSColor($0).hexString }
        )
    }
}
