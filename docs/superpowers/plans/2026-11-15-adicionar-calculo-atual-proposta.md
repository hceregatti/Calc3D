# Renomear cálculos e adicionar cálculo atual à proposta Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir renomear cálculos já salvos e enviar o cálculo atual diretamente para uma proposta nova ou existente.

**Architecture:** Manter `QuoteRecord` imutável fora da persistência e, ao renomear, substituir o snapshot com o mesmo ID/data e o mesmo resultado. O painel da calculadora criará um snapshot temporário do resultado atual, permitirá escolher o destino e salvará a proposta com um novo item independente.

**Tech Stack:** Swift 6, SwiftUI, AppKit, `UserDefaults` JSON já existente; sem dependências externas.

**Spec:** `docs/superpowers/specs/2026-11-15-adicionar-calculo-atual-proposta-design.md`

## Global Constraints

- Implementar diretamente na branch `main`, sem criar worktree.
- Fazer um commit separado para cada entrega funcional.
- Manter macOS 14 como versão mínima.
- Renomear não recalcula nem altera dados de custo, preço, parâmetros ou data.
- Adicionar da calculadora não salva nem altera a coleção de cálculos simples.
- O item de proposta usa nome/preço copiados e não aponta para um `QuoteRecord` salvo.
- Bloquear inclusão se `result.suggestedPrice` não for finito/válido.
- Preservar ou pedir confirmação antes de descartar alterações não salvas em uma proposta.

## Review Focus

- Nome vazio ou só com espaços não deve substituir um nome válido.
- Renomear um cálculo mantém ID, data, parâmetros e resultado, inclusive após recarregar persistência.
- Inclusão com preço indisponível não pode criar item com valor zero.
- Inclusão para uma proposta existente altera apenas o destino selecionado.
- Iniciar inclusão enquanto há rascunho alterado exige confirmação e usa os valores do cálculo capturados ao iniciar a ação.

---

### Task 1: Renomear cálculo salvo

**Files:**
- Modify: `Sources/Calc3D/ViewModels/CalculatorViewModel.swift`
- Modify: `Sources/Calc3D/Views/QuotesView.swift`

**Interfaces:**
- ViewModel: `func updateQuoteNameDraft(_ name: String, for quoteID: UUID)` mantém texto de edição temporário.
- ViewModel: `func quoteNameHasUnsavedChanges(for quote: QuoteRecord) -> Bool` habilita o botão somente para nome não vazio e alterado.
- ViewModel: `func saveQuoteName(for quote: QuoteRecord)` substitui o registro com o mesmo ID/data e dados de impressão/parâmetros/resultado; só troca `job.name` e salva em `QuotesStore`.
- `QuoteDetail` recebe binding de nome e callback de salvamento; botão fica junto ao nome do cálculo.

- [x] Adicionar rascunho de nome no `CalculatorViewModel` identificado pelo UUID do cálculo.
- [x] Implementar salvamento validando nome aparado não vazio e preservando todos os demais campos do snapshot.
- [x] Adicionar campo editável e botão “Salvar nome” no detalhe do cálculo; refletir nome novo na lista.
- [x] Executar `git diff --check` e `./scripts/build-app.sh`.
- [x] Commit: `feat: permite renomear cálculos salvos` (`e872536`).

### Task 2: Adicionar resultado atual da calculadora à proposta

**Files:**
- Modify: `Sources/Calc3D/ViewModels/CalculatorViewModel.swift`
- Modify: `Sources/Calc3D/Views/ResultsPanel.swift`
- Modify: `Sources/Calc3D/Views/ContentView.swift`
- Modify: `Sources/Calc3D/Views/ProposalsView.swift`

**Interfaces:**
- `func addCurrentCalculationToProposal(_ proposalID: UUID?)` captura `job`, `settings` e `result` atuais, cria `ProposalItem(name: job.name, unitPrice: result.suggestedPrice, sourceQuoteID: nil)`, salva o destino e navega para seu editor.
- `nil` como destino cria e salva uma proposta com título inicial “Nova proposta”; UUID aponta a uma proposta salva que recebe o novo item.
- `ProposalDraftAction` ganha caso que preserva o snapshot e destino até a confirmação de descarte do rascunho atual.
- `ResultsPanel` oferece menu “Adicionar à proposta” com nova proposta e cada proposta salva; desabilita quando não há preço sugerido válido.

- [x] Implementar captura segura do cálculo atual e criação de item sem referência a cálculo salvo.
- [x] Implementar criação de proposta ou anexação ao UUID escolhido, salvando imediatamente e abrindo a área “Propostas”.
- [x] Integrar a confirmação existente de descarte de rascunho com a ação pendente de inclusão, preservando o snapshot capturado. O diálogo foi movido para `ContentView` após a revisão indicar que ele precisava permanecer ativo ao iniciar pela calculadora.
- [x] Adicionar menu no painel de resultado, bloquear preço indisponível e nomear destinos existentes.
- [x] Executar `git diff --check` e `./scripts/build-app.sh`.
- [x] Commits: `feat: adiciona cálculo atual às propostas` (`24221ee`) e `fix: mostra confirmação ao incluir cálculo atual` (`63e5a33`).

### Revisão final

- [x] Conferir critérios de `docs/superpowers/specs/2026-11-15-adicionar-calculo-atual-proposta-design.md`.
- [x] Executar `git diff --check` e `./scripts/build-app.sh` após os commits, incluindo a correção da revisão.
- [x] Confirmar commits separados e árvore de código limpa após o commit de documentação.
