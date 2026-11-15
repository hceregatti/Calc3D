# Calculadora 3D: orçamentos e arquivos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar histórico local de orçamentos, importação de STL/3MF do Bambu Studio e salvamento explícito dos parâmetros fixos.

**Architecture:** Preservar o motor de cálculo existente e colocar armazenamento/parser no alvo do app. Orçamentos armazenam snapshots dos dados e resultados; a navegação SwiftUI ganha uma tela de histórico e a tela de impressão recebe a importação; parâmetros fixos passam a persistir somente quando confirmados no botão.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, `Codable`, macOS 14+, sem dependências externas.

**Spec:** [2026-11-15-calculadora-orcamentos-importacao-design.md](../specs/2026-11-15-calculadora-orcamentos-importacao-design.md)

## Global Constraints

- Aplicativo nativo macOS, SwiftUI, Swift 6, macOS 14+.
- Não alterar fórmulas ou resultados do `CostCalculator`.
- Não inferir peso nem tempo a partir de malha STL/3MF.
- Campos ausentes em arquivo importado ficam zerados e indicados para preenchimento; falhas de leitura não modificam o formulário.
- Reconhecer somente estimativas explícitas presentes em metadados Bambu Studio; arquivos 3MF sem dados fatiados e STL importam o nome e solicitam peso/tempo.
- Persistência é local e versionada em JSON; orçamentos conservam seus snapshots mesmo após mudança dos parâmetros fixos.
- Não adicionar nem executar testes automatizados nesta implementação.

## Review Focus

- Importar 3MF comum ainda não fatiado não pode preservar peso/tempo anteriores ou os valores padrão; verificar manualmente que ambos são zerados e sinalizados.
- Metadados de peso por múltiplos filamentos devem resultar na soma em gramas, sem contar duplicado; verificar com arquivo Bambu Studio fatiado de amostra.
- Duração ausente, zero, inválida ou em formato desconhecido deve permanecer pendente, sem valor estimado.
- Arquivo corrompido, extensão não suportada e cancelamento do seletor não devem alterar a impressão atual.
- Snapshot histórico deve manter preço, custos detalhados, dados da impressão e parâmetros originais após mudanças e após reabrir o app.

## File Structure

- `Sources/Calc3DCore/CostResult.swift`: tornar os tipos de resultado serializáveis para snapshots.
- `Sources/Calc3D/Models/QuoteRecord.swift` (novo): registro imutável de orçamento com UUID, data, `PrintJob`, `ShopSettings` e `CostResult`.
- `Sources/Calc3D/Persistence/QuotesStore.swift` (novo): leitura/escrita versionada do histórico em JSON local.
- `Sources/Calc3D/ViewModels/CalculatorViewModel.swift`: ações para salvar, selecionar e usar registro como base; controlar estado pendente dos parâmetros.
- `Sources/Calc3D/Views/QuotesView.swift` (novo): lista de registros, detalhes somente leitura e ação para reutilizar.
- `Sources/Calc3D/Views/ContentView.swift`: adicionar item de navegação “Orçamentos”.
- `Sources/Calc3D/Views/ResultsPanel.swift`: ação “Salvar orçamento” e feedback de salvamento.
- `README.md`: atualizar as telas, atalhos e instruções de importação.
- `Sources/Calc3D/Import/ModelFileImporter.swift` (novo): extração de nome STL/3MF e metadados Bambu Studio suportados, retornando dados opcionais.
- `Sources/Calc3D/Views/PrintJobView.swift`: botão de importação, seletor do macOS e indicação de campos ausentes.
- `Sources/Calc3D/Views/ShopSettingsView.swift`: botão explícito de salvar, estado alterado/salvo e restauração de padrões pendente.
- `Sources/Calc3D/Persistence/ParametersStore.swift`: já oferece o método explícito `save(_:)`; será reutilizado sem alterar seu contrato.

## Tasks

### Task 1: Snapshot serializável e armazenamento do histórico

**Files:**
- Modify: `Sources/Calc3DCore/CostResult.swift`
- Create: `Sources/Calc3D/Models/QuoteRecord.swift`
- Create: `Sources/Calc3D/Persistence/QuotesStore.swift`

**Interfaces:**
- `QuoteRecord`: `Codable`, `Identifiable`, `Equatable`, `Sendable`; propriedades `id: UUID`, `savedAt: Date`, `job: PrintJob`, `settings: ShopSettings`, `result: CostResult`.
- `QuotesStore.load() -> [QuoteRecord]`
- `QuotesStore.save(_ records: [QuoteRecord])`

- [x] Tornar `CostCategory`, `CostItem`, `PricingError` e `CostResult` codificáveis, incluindo os casos de sucesso e falha do preço.
- [x] Criar `QuoteRecord` como snapshot completo; manter o resultado gravado para que o histórico não dependa de recalcular com parâmetros atuais.
- [x] Criar armazenamento JSON com chave versionada própria; tratar dados ausentes ou inválidos como histórico vazio e ordenar registros do mais recente ao mais antigo.

### Task 2: Fluxo de salvar e consultar orçamentos

**Files:**
- Modify: `Sources/Calc3D/ViewModels/CalculatorViewModel.swift`
- Modify: `Sources/Calc3D/Views/ContentView.swift`
- Modify: `Sources/Calc3D/Views/ResultsPanel.swift`
- Modify: `README.md`
- Create: `Sources/Calc3D/Views/QuotesView.swift`

**Interfaces:**
- View model: `saveQuote()`, `useQuoteAsBase(_ quote: QuoteRecord)`, propriedade somente leitura `quotes: [QuoteRecord]`, `selectedQuoteID: UUID?` e estado de feedback.
- `Screen.quotes` com título “Orçamentos” e ícone apropriado.

- [x] Carregar o histórico ao iniciar o view model e persistir por `QuotesStore` ao salvar um orçamento.
- [x] Na ação de salvar, capturar conjuntamente impressão, parâmetros fixos e resultado atuais, adicionando data e UUID.
- [x] Adicionar “Salvar orçamento” ao painel de resultados, permitindo também arquivar um cálculo com erro de precificação e apresentando confirmação visual ao salvar.
- [x] Implementar a tela de lista e detalhe somente leitura com nome, data, preço, dados de impressão e composição do custo.
- [x] Guardar a seleção de orçamento no view model (sem introduzir `@State`) para compatibilidade com o padrão de estado do app.
- [x] Implementar “Usar como base” copiando apenas o `PrintJob` histórico e mantendo os parâmetros fixos atuais; navegar para Impressão.

### Task 3: Importação de STL e 3MF do Bambu Studio

**Files:**
- Create: `Sources/Calc3D/Import/ModelFileImporter.swift`
- Modify: `Sources/Calc3D/Views/PrintJobView.swift`
- Modify: `Sources/Calc3D/ViewModels/CalculatorViewModel.swift`

**Interfaces:**
- `ImportedModelData`: nome do modelo e valores opcionais de peso (g) e duração (segundos ou horas, normalizados antes de atualizar `PrintJob`).
- `ModelFileImporter.importFile(at url: URL) throws -> ImportedModelData`
- View model: `applyImportedModel(_ data: ImportedModelData)`.

- [x] Implementar leitura de STL para extrair o nome do arquivo e aceitar tanto STL binário como ASCII sem calcular volume/peso.
- [x] Implementar leitura de arquivos 3MF ZIP sem extrair caminhos arbitrários, usando argumentos separados do processo (sem shell) para ler apenas `Metadata/slice_info.config`. Reconhecer `prediction` por placa para duração em segundos e `used_g` para peso por filamento, conforme a estrutura exportada pelo [código do Bambu Studio](https://github.com/bambulab/BambuStudio/blob/master/src/libslic3r/Format/bbs_3mf.cpp).
- [x] Somar uma única vez os valores `used_g` associados à placa que contém `prediction`; se não houver exatamente uma placa com estimativas válidas, retornar peso/tempo como ausentes. Distinguir projetos 3MF sem fatiamento de arquivos 3MF fatiados.
- [x] Abrir seletor nativo macOS para `.stl` e `.3mf`; executar leitura fora da thread principal e tratar erro/cancelamento sem tocar nos dados atuais.
- [x] Ao importar com sucesso, usar o nome base do arquivo; substituir peso/tempo somente pelos valores explícitos importados, zerar campos ausentes e mostrar mensagem com os dados encontrados e pendentes.

### Task 4: Salvamento explícito dos parâmetros fixos

**Files:**
- Modify: `Sources/Calc3D/ViewModels/CalculatorViewModel.swift`
- Modify: `Sources/Calc3D/Views/ShopSettingsView.swift`

**Interfaces:**
- View model: `settingsHaveUnsavedChanges: Bool`, `saveSettings()` e feedback de confirmação.

- [x] Reter a última versão persistida em memória e comparar com `settings` para derivar o estado pendente.
- [x] Remover o salvamento implícito de parâmetros fixos do `didSet`; conservar recálculo imediato e salvamento atual dos dados da impressão.
- [x] Adicionar botão “Salvar parâmetros”, ativo apenas quando houver alterações, e exibir estado “Salvo”/“Alterações não salvas”.
- [x] Fazer “Restaurar padrões” marcar alterações pendentes; persistir os valores somente quando a pessoa clicar em salvar.

## Manual Review (not performed)

These checks were not run because the current instruction set prohibits adding or running tests or verification unless explicitly requested.

- Abrir o app e confirmar as três telas e a navegação, incluindo orçamento recém-salvo na lista.
- Salvar um orçamento, alterar parâmetros, fechar/reabrir o app e confirmar que o histórico conserva os valores originais.
- Importar STL e 3MF Bambu Studio com e sem fatiamento; confirmar preenchimento explícito e pendências.
- Cancelar seletor e escolher um arquivo inválido; confirmar que o formulário não muda.
- Alterar vários parâmetros, observar estado pendente, salvar e reiniciar para confirmar persistência; restaurar padrões sem salvar e confirmar que o armazenamento não muda.
