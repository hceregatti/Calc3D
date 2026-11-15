# Histórico de orçamentos, importação de modelos e salvamento de parâmetros

## Intenção

Dar à pessoa que usa a Calculadora 3D três formas de preservar e reutilizar seu trabalho: arquivar orçamentos calculados, iniciar uma impressão a partir de um arquivo de modelo e salvar explicitamente alterações dos parâmetros fixos.

## Objetivos

- Adicionar uma tela Orçamentos que lista registros salvos, persiste entre aberturas e permite reabrir um orçamento com os dados e parâmetros originais.
- Adicionar importação de arquivos de impressão, aproveitando peso e tempo fornecidos pelos metadados do fatiador quando encontrados.
- Para arquivos sem estimativas utilizáveis, preencher o nome com o nome do arquivo e deixar peso e tempo para a pessoa completar; não inventar estimativas a partir da malha.
- Incluir um botão Salvar parâmetros fixos, habilitado quando houver alterações ainda não confirmadas, e indicar quando estão salvos.
- Manter os fluxos e fórmulas atuais de cálculo e a persistência local.

## Fora de escopo

- Fatiar modelos, estimar tempo de impressão, ou calcular peso pela geometria.
- Sincronização em nuvem, exportação de orçamento ou anexar os arquivos de modelo ao histórico.
- Editar parâmetros fixos dentro de um orçamento histórico.

## Abordagens consideradas

1. **Usar metadados de fatiador quando presentes; solicitar os valores faltantes.** Recomendado e escolhido: aproveita dados reais incluídos em projetos 3MF e mantém entrada manual clara para STL e arquivos sem metadados.
2. **Estimar peso pela geometria.** Rejeitado: STL/3MF não definem necessariamente densidade, preenchimento, suportes ou perfil; a estimativa poderia ser confundida com dado real. Ainda assim não fornece tempo de impressão confiável.

## Comportamento

### Orçamentos

- A ação “Salvar orçamento” registra uma cópia do nome, dados da impressão, parâmetros fixos, resultado calculado e data/hora do salvamento.
- A lista “Orçamentos” mostra nome (ou “Orçamento sem nome”), preço sugerido quando disponível, e data; selecionar um registro abre seus detalhes em modo somente leitura.
- Uma ação “Usar como base” copia os dados da impressão para a tela de Impressão e volta a aplicar os parâmetros fixos atuais; o registro original não é alterado.
- Os registros ficam no armazenamento local, em JSON versionado, seguindo o padrão de `ParametersStore`.

### Importação de modelos

- A ação “Importar arquivo…” usa o seletor de arquivos do macOS. A primeira entrega aceita STL e 3MF. Outros formatos de malha e arquivos de projeto de fatiador ficam fora da primeira versão até que haja amostras para validar o suporte.
- Para 3MF, ler o contêiner ZIP/XML e reconhecer metadados explícitos de peso e duração total de impressão gravados pelo Bambu Studio. Para STL, obter o nome do arquivo e não tentar inferir material ou tempo.
- Peso e duração preenchidos pelo arquivo aparecem na forma atual e permanecem editáveis. Ao importar um arquivo, valores ausentes são limpos (zero) e marcados para preenchimento, evitando que valores padrão ou de outro modelo contaminem o orçamento. A tela informa quais dados foram encontrados e quais precisam ser preenchidos.
- Arquivo inválido ou não suportado gera mensagem recuperável sem alterar os campos atuais.

### Parâmetros fixos

- Alterações continuam refletidas no cálculo atual, mas o salvamento persistente passa a ser explícito pelo botão “Salvar parâmetros”.
- O botão só fica habilitado quando as configurações diferem da última versão salva. Ao salvar, persiste todas as propriedades existentes de `ShopSettings` e apresenta confirmação visual.
- Ao restaurar padrões, a tela marca as alterações como pendentes até serem salvas.

## Restrições e escolhas do projeto

- Aplicativo macOS nativo, SwiftUI, Swift 6, macOS 14+, sem dependências externas presumidas.
- Preservar o motor puro de `Calc3DCore`; parser de arquivos e armazenamento ficam no alvo do app ou em modelos puros apropriados.
- Tratar conteúdo 3MF como ZIP/XML potencialmente malformado e nunca bloquear a interface durante a leitura.
- O formato dos metadados varia entre fatiadores. A primeira versão deve declarar que metadados do Bambu Studio são reconhecidos e ignorar campos não reconhecidos.

## Deixado ao implementador

- O formato interno versionado dos registros e o mapeamento exato de campos de metadados do Bambu Studio, limitado a padrões observáveis em arquivos de amostra disponíveis.
- A organização visual concreta da lista e detalhes, seguindo os componentes SwiftUI existentes.
- Testes automatizados do histórico, do parser e do estado de salvamento, além de verificação manual da experiência de seleção de arquivo.
