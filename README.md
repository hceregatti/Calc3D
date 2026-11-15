# Calculadora 3D

App nativo para macOS (SwiftUI, Apple Silicon) que calcula o custo real e o preço de venda de peças impressas em 3D.

## Requisitos

- macOS 14 Sonoma ou superior, Mac com Apple Silicon (M1 a M4)
- Swift 6 (Command Line Tools: `xcode-select --install`) ou Xcode

## Comandos

```bash
make app       # compila em release e gera build/Calculadora 3D.app
make open      # gera e abre o app
make install   # copia o app para /Applications
make run       # executa em modo debug
make test      # roda os testes do motor de cálculo
make clean
```

## Estrutura

```
Package.swift
Sources/
  Calc3DCore/                  # Regras de negócio puras, sem UI (testáveis)
    PrintParameters.swift      #   parâmetros de entrada + valores padrão
    CostCalculator.swift       #   motor de cálculo (todas as fórmulas)
    CostResult.swift           #   resultado, categorias, erros de precificação
    QuoteSummary.swift         #   texto do orçamento + formatação em R$
  Calc3D/                      # App macOS (SwiftUI)
    App/Calc3DApp.swift        #   ponto de entrada, janela e menus
    ViewModels/                #   estado da tela (Observation)
    Persistence/               #   salva parâmetros no UserDefaults
    Views/                     #   formulário, painel de resultados, componentes
Tests/Calc3DCoreTests/         # testes (swift-testing)
Resources/Info.plist           # metadados do bundle .app
scripts/
  build-app.sh                 # build release + montagem e assinatura do .app
  make-icon.swift              # gera o ícone do app em código
```

## Modelo de custo

| Componente | Fórmula |
|---|---|
| Filamento | peso × (1 + desperdício) × preço do rolo ÷ peso do rolo |
| Energia | W ÷ 1000 × horas × tarifa |
| Depreciação | (preço − revenda) ÷ vida útil × horas |
| Manutenção | manutenção anual ÷ horas/ano × horas |
| Custos fixos | fixos mensais ÷ horas/mês × horas |
| Falhas | (filamento + energia + máquina + fixos) × f ÷ (1 − f) |
| Mão de obra | (preparação + pós) ÷ 60 × valor/h |
| Insumos | insumos por mesa + embalagem × peças |
| **Preço** | (custo/peça + taxa fixa) ÷ (1 − margem − impostos − taxa %) |

Peso e tempo são da mesa inteira; o custo é dividido pelo número de peças.

## Notas de build sem Xcode

- Os macros `@State` e `#Preview` do SwiftUI dependem de plugins que só vêm com o Xcode, então o projeto não usa nenhum dos dois.
- O `make test` passa ao compilador os caminhos do swift-testing que existem nas Command Line Tools.
- O app é assinado ad-hoc. Se for copiado para outro Mac, o Gatekeeper pode pedir para liberar o app em
  Ajustes do Sistema › Privacidade e Segurança.
