# Calc3D

App nativo para macOS (SwiftUI, Apple Silicon) que calcula o custo real e o preço de venda de peças impressas em 3D.

Também há uma **versão web** em [`web/`](web/) que roda inteira no navegador (veja [Versão web](#versão-web)).

## Requisitos

- macOS 14 Sonoma ou superior, Mac com Apple Silicon (M1 a M4)
- Swift 6 (Command Line Tools: `xcode-select --install`) ou Xcode

## Comandos

```bash
make app       # compila em release e gera build/Calc3D.app
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
    ShopSettings.swift         #   parâmetros fixos + custos por hora derivados
    PrintJob.swift             #   dados de cada impressão
    CostCalculator.swift       #   motor de cálculo (todas as fórmulas)
    CostResult.swift           #   resultado, categorias, erros de precificação
    QuoteSummary.swift         #   texto do orçamento + formatação em R$
  Calc3D/                      # App macOS (SwiftUI)
    App/Calc3DApp.swift        #   ponto de entrada, janela e menus
    ViewModels/                #   estado da tela (Observation)
    Persistence/               #   salva parâmetros no UserDefaults
    Views/
      ContentView.swift        #   barra lateral com as duas telas
      PrintJobView.swift       #   tela de impressão: dados da peça + resultado
      ShopSettingsView.swift   #   tela de parâmetros fixos
      ResultsPanel.swift       #   preço, indicadores e composição do custo
Tests/Calc3DCoreTests/         # testes (swift-testing)
Resources/Info.plist           # metadados do bundle .app
scripts/
  build-app.sh                 # build release + montagem e assinatura do .app
  make-icon.swift              # gera o ícone do app em código
```

## Telas

- **Início** (⌘1): atalhos (calcular peça, novo orçamento), números gerais e peças/orçamentos recentes.
- **Calcular peça** (⌘2): o que muda a cada peça. Nome, peso e tempo do fatiador, peças por mesa,
  preparação, pós-processamento, insumos e margem, com o resultado ao lado. "Salvar peça" guarda
  o cálculo no histórico; "Adicionar a orçamento" inclui o cálculo atual direto em um orçamento.
- **Peças** (⌘3): histórico de cálculos de peças, com os parâmetros originais. Selecione várias
  (⌘-clique/⇧-clique) para gerar um orçamento ou adicioná-las a um orçamento existente.
- **Orçamentos** (⌘4): orçamentos com várias peças, quantidades, cliente e exportação em PDF.
  "Calcular nova peça…" abre o mesmo formulário da tela Calcular peça (inclusive importação de
  STL/3MF) e adiciona o preço sugerido ao orçamento, opcionalmente salvando a peça no histórico.
  "Adicionar do histórico…" inclui várias peças já salvas de uma vez.
- **Personalizar orçamento** (⌘5): logo, dados e contatos da empresa, cor do PDF, rodapé,
  numeração e condições padrão (validade, pagamento, prazo, observações). Cada produto do
  orçamento aceita uma foto; sem foto, o PDF usa uma imagem padrão.
- **Parâmetros fixos** (⌘6 ou ⌘,): configurados uma vez. Filamento padrão, energia, máquina,
  valor da hora, embalagem, custos fixos, taxa de falha, impostos e taxas de venda.
  Mostra quanto custa uma hora de máquina e permite salvar alterações explicitamente.

Na tela Calcular peça, importe arquivos STL ou 3MF do Bambu Studio. Arquivos fatiados podem preencher peso e tempo quando os metadados estiverem disponíveis; nos demais casos, preencha os valores do fatiador.

⌘N inicia uma nova peça, ⇧⌘N cria um novo orçamento e ⇧⌘C copia o resumo da peça.

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

## Versão web

Em `web/` está a mesma calculadora em React + TypeScript (Vite), sem servidor: tudo roda e fica
salvo no navegador (localStorage para os dados, IndexedDB para logo e fotos). As fórmulas são
uma tradução direta do `Calc3DCore`, com os mesmos testes.

Requer Node.js 18+.

```bash
make web        # instala dependências e abre em http://localhost:5173
make web-test   # testes do cálculo e dos orçamentos (vitest)
make web-build  # gera web/dist/, pronto para hospedar em qualquer servidor estático
```

- **PDF**: "Gerar PDF" abre a visualização; "Imprimir / Salvar PDF" usa a impressão do navegador
  (escolha "Salvar como PDF" e desmarque "Cabeçalhos e rodapés"). Rodapé e número de página em
  todas as folhas funcionam no Chrome/Edge.
- **Backup**: os dados ficam só no navegador onde foram criados. Em Parâmetros fixos → Backup dos
  dados, exporte um arquivo JSON (inclui as imagens) para guardar ou importar em outro computador.
- **Hospedagem**: `web/dist/` usa caminhos relativos, então funciona no GitHub Pages, Netlify,
  Vercel ou em qualquer pasta de um servidor.
