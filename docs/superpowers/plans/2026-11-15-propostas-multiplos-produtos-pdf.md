# Propostas com vários produtos e PDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir excluir cálculos salvos e criar propostas comerciais locais com vários itens manuais ou copiados de cálculos, exportáveis em PDF sob demanda.

**Architecture:** Preservar `QuoteRecord` como snapshot de um cálculo de impressão e criar modelos e persistência próprios para propostas. A interface “Orçamentos” terá áreas para cálculos individuais e propostas; cada item da proposta guarda uma cópia dos dados usados, e um exportador nativo produz o PDF no caminho escolhido pelo usuário.

**Tech Stack:** Swift 6, SwiftUI, AppKit, CoreGraphics/CoreText, JSON em `UserDefaults`; sem dependências externas.

**Spec:** `docs/superpowers/specs/2026-11-15-propostas-multiplos-produtos-pdf-design.md`

## Global Constraints

- Implementar diretamente na branch `main`, sem criar worktree.
- Fazer um commit separado por entrega funcional indicada abaixo.
- Manter macOS 14 como versão mínima e usar APIs nativas.
- Manter a calculadora de impressão separada dos dados e do ciclo de vida de propostas.
- Persistir propostas numa coleção/chave versionada própria; não alterar o formato atual de `QuoteRecord`.
- Cópias de cálculos salvos dentro de propostas permanecem válidas se o cálculo original for removido.
- Dados do cliente são opcionais; o PDF só é criado mediante ação explícita do usuário.

## Review Focus

- Excluir um cálculo selecionado deve persistir a remoção e selecionar outro registro disponível ou limpar a seleção.
- Um cálculo sem preço sugerido não deve produzir silenciosamente item de proposta com preço zero.
- Apagar ou editar o cálculo de origem não deve alterar a cópia armazenada na proposta.
- Quantidade inválida/zero e preço não finito ou negativo não devem gerar totais ou PDFs incorretos.
- Descrições longas e propostas com muitos itens devem continuar legíveis em páginas subsequentes do PDF.
- Proposta sem itens não deve permitir exportação de um documento comercial vazio.

---

### Task 1: Excluir cálculo individual salvo

**Files:**
- Modify: `Sources/Calc3D/ViewModels/CalculatorViewModel.swift`
- Modify: `Sources/Calc3D/Views/QuotesView.swift`

**Interfaces:**
- Produces: `func deleteQuote(_ quote: QuoteRecord)` remove por `id`, persiste em `QuotesStore` e atualiza `selectedQuoteID`.
- UI: ação de excluir no detalhe selecionado com alerta de confirmação contendo o nome do cálculo.

- [x] Adicionar estado/ação de confirmação no detalhe do cálculo e remover somente após confirmação explícita.
- [x] Implementar `deleteQuote(_:)`, salvar a coleção atualizada e ajustar a seleção sem deixar ID órfão.
- [x] Executar `git diff --check` e `./scripts/build-app.sh`.
- [x] Commit: `feat: permite excluir cálculos salvos` (`1ed82c5`).

### Task 2: Modelo e armazenamento de propostas

**Files:**
- Create: `Sources/Calc3D/Models/ProposalRecord.swift`
- Create: `Sources/Calc3D/Persistence/ProposalsStore.swift`
- Modify: `Sources/Calc3D/ViewModels/CalculatorViewModel.swift`

**Interfaces:**
- `ProposalItem`: `id: UUID`, `name: String`, `details: String`, `quantity: Int`, `unitPrice: Double`, `sourceQuoteID: UUID?`; subtotal derivado de quantidade × preço. Campos comerciais são snapshots.
- `ProposalRecord`: `id: UUID`, `title: String`, `createdAt: Date`, `updatedAt: Date`, `customerName: String`, `customerContact: String`, `items: [ProposalItem]`; `total: Double` derivado da soma dos subtotais.
- `ProposalsStore`: carregar/salvar payload JSON versionado em chave própria, mantendo o padrão de `QuotesStore`.
- `CalculatorViewModel`: carregar `proposals` na inicialização; operações de salvar e excluir proposta; seleção de proposta separada de `selectedQuoteID`.

- [x] Criar os modelos Codable/Equatable/Identifiable com valores padrão seguros e totais derivados.
- [x] Criar `ProposalsStore` com versão e chave próprias, sem modificar a persistência atual de cálculos.
- [x] Integrar carregamento e mutações da coleção ao `CalculatorViewModel`.
- [x] Executar `git diff --check` e `./scripts/build-app.sh`.
- [x] Commit: `feat: adiciona persistência de propostas` (`d99d6f6`).

### Task 3: Lista, edição e itens manuais

**Files:**
- Modify: `Sources/Calc3D/Views/QuotesView.swift`
- Create: `Sources/Calc3D/Views/ProposalsView.swift`
- Create: `Sources/Calc3D/Views/ProposalEditorView.swift`
- Modify: `Sources/Calc3D/ViewModels/CalculatorViewModel.swift`

**Interfaces:**
- `QuotesView` oferece seletor interno entre “Cálculos salvos” e “Propostas”, mantendo a tela e rota lateral existentes.
- `ProposalsView` lista propostas por atualização mais recente, inicia proposta nova e seleciona proposta para edição.
- `ProposalEditorView` edita título, cliente/contato opcionais e itens; permite adicionar item manual, alterar quantidade/preço, remover item e salvar explicitamente.
- Uma proposta vazia pode ser salva como rascunho, mas não exportada até ter ao menos um item válido.

- [x] Adicionar navegação interna entre a lista existente de cálculos e propostas.
- [x] Implementar criação/listagem/seleção de propostas persistidas e edição de título e campos opcionais.
- [x] Incluir ação de excluir proposta com confirmação e persistir sem afetar outras propostas ou cálculos.
- [x] Implementar inclusão/edição/remoção de itens manuais, quantidade positiva e preço unitário finito não negativo.
- [x] Mostrar subtotais e total recalculados; salvar alterações explicitamente e atualizar `updatedAt`.
- [x] Executar `git diff --check` e `./scripts/build-app.sh`.
- [x] Commit: `feat: permite montar propostas com itens manuais` (`b0ca006`).

### Task 4: Adicionar cálculos salvos às propostas

**Files:**
- Modify: `Sources/Calc3D/Views/ProposalEditorView.swift`
- Modify: `Sources/Calc3D/ViewModels/CalculatorViewModel.swift`

**Interfaces:**
- Ação “Adicionar cálculo salvo” apresenta cálculos disponíveis e cria `ProposalItem` com nome, preço sugerido e referência de origem.
- Cálculos sem `suggestedPrice` são identificados como indisponíveis e não podem ser adicionados como item calculado.
- Adicionar cálculo apenas copia dados para a proposta; a persistência da proposta não depende do cálculo de origem.

- [x] Implementar escolha de cálculos salvos no editor, desabilitando os sem preço válido.
- [x] Copiar nome/preço e referência para um item independente, com quantidade inicial 1.
- [x] Confirmar no código que exclusão/edição da origem não propaga alterações ao snapshot.
- [x] Executar `git diff --check` e `./scripts/build-app.sh`.
- [x] Commit: `feat: adiciona cálculos salvos às propostas` (`c8798d1`).

### Task 5: Gerar PDF sob demanda

**Files:**
- Create: `Sources/Calc3D/Export/ProposalPDFExporter.swift`
- Modify: `Sources/Calc3D/Views/ProposalEditorView.swift`
- Modify: `Sources/Calc3D/ViewModels/CalculatorViewModel.swift`

**Interfaces:**
- `ProposalPDFExporter.write(_ proposal: ProposalRecord, to url: URL) throws` gera PDF vetorial usando frameworks nativos, incluindo título, data, cliente/contato quando informados, itens, quantidades, preços unitários, subtotais e total.
- Exportação usa `NSSavePanel`, sugere nome de arquivo baseado no título e permanece desabilitada sem itens válidos.
- O exportador cria páginas adicionais quando os itens excedem o espaço disponível e quebra textos longos sem cortar conteúdo.

- [x] Implementar renderização de PDF multipágina e formatação monetária pt-BR sem biblioteca externa.
- [x] Adicionar ação de exportação ao editor e gravar no URL escolhido; apresentar erro recuperável se a gravação falhar.
- [x] Executar `git diff --check` e `./scripts/build-app.sh`.
- [ ] Inspecionar visualmente PDFs curtos e longos; não realizado nesta sessão.
- [x] Commit: `feat: exporta propostas comerciais em PDF` (`043101c`).

### Task 6: Revisão final

- [x] Revisar a implementação contra todos os critérios de `docs/superpowers/specs/2026-11-15-propostas-multiplos-produtos-pdf-design.md`.
- [x] Executar `git diff --check` e `./scripts/build-app.sh` após todos os commits.
- [x] Confirmar que as alterações de código estão em commits separados por entrega; documentação será registrada em commit próprio.
