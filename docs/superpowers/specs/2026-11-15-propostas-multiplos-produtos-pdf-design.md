# Propostas com vários produtos e PDF

## Intenção

Permitir excluir cálculos individuais salvos e criar propostas comerciais independentes da tela de impressão. Uma proposta pode reunir produtos cadastrados manualmente e resultados de cálculos simples já salvos, permanecer salva para edição e ser exportada em PDF quando necessário.

## Objetivos

- Adicionar exclusão de um cálculo salvo na lista de “Orçamentos”, com confirmação antes de removê-lo.
- Permitir criar e salvar propostas com vários itens sem exigir que cada item passe pela calculadora de impressão.
- Permitir excluir uma proposta salva com confirmação, assim como um cálculo individual.
- Permitir incluir numa proposta um cálculo simples já salvo, preservando nome e preço como fotografia dos dados no momento da inclusão.
- Permitir editar e excluir itens, informar quantidades, identificar o cliente opcionalmente e salvar a proposta localmente.
- Gerar sob demanda um PDF compartilhável com cliente, data, itens, quantidades, valores unitários, subtotais e total.
- Manter cálculos de impressão e propostas como registros distintos. Apagar o cálculo de origem não altera uma proposta que já contém sua cópia dos dados.

## Fora de escopo

- Enviar o PDF diretamente por e-mail ou serviço externo.
- Exigir cliente, logo, endereço, prazo de validade ou dados fiscais para salvar uma proposta.
- Alterar o cálculo de custo/preço existente ou obrigar que todo orçamento venha de uma impressão.

## Abordagens consideradas

1. **Editor de propostas separado da calculadora (recomendada e aprovada):** a proposta contém itens manuais e/ou cópias de cálculos simples salvos. Isso cobre produtos que não serão impressos e preserva o fluxo da calculadora.
2. **Agrupar somente cálculos salvos:** reaproveita os registros atuais com menos interface, mas continua exigindo um cálculo de impressão para cada produto.

## Experiência e comportamento

- A lista atual de cálculos salvos oferece uma ação de excluir para o registro selecionado. A confirmação identifica o registro; cancelar não altera a lista nem a persistência.
- A área “Orçamentos” permite iniciar uma proposta independente, listar propostas salvas e abrir uma para continuar editando ou exportar.
- Uma proposta salva pode ser excluída com confirmação sem afetar cálculos salvos ou outras propostas.
- O editor permite adicionar item manual com nome, descrição opcional, quantidade e preço unitário; também permite escolher um cálculo simples salvo e copiar nome/preço para um novo item.
- Itens importados do cálculo são cópias: nome e preço da proposta não mudam quando o cálculo original é editado ou apagado.
- Dados do cliente são opcionais. Os totais são recalculados como quantidade × preço unitário e somados para o total da proposta.
- Salvar uma proposta não gera automaticamente um PDF. A ação “Exportar PDF” abre o diálogo nativo de salvamento, permitindo gerar ou atualizar o arquivo quando necessário.
- A proposta salva permanece disponível mesmo se o cálculo de impressão que originou algum item for excluído.

## Persistência e implementação

- Seguir o padrão local de armazenamento JSON versionado já usado por `QuotesStore`, mantendo propostas numa coleção e chave próprias.
- Representar cada proposta por identificador, datas de criação/atualização, dados opcionais do cliente e itens. Cada item armazena seu próprio nome, descrição, quantidade e preço unitário.
- Usar os frameworks nativos do macOS para gerar PDF paginado e apresentar `NSSavePanel`; não adicionar dependências externas.
- Manter a calculadora de impressão e o registro `QuoteRecord` existentes compatíveis com seus dados atuais.

## Critérios de aceitação

- Um cálculo salvo pode ser excluído após confirmação e deixa de aparecer após reabrir o app.
- Uma proposta pode combinar item manual e item copiado de cálculo salvo, ser salva, reaberta e continuar editável.
- Uma proposta pode ser excluída após confirmação sem apagar registros relacionados.
- Excluir um cálculo de origem não apaga nem altera itens das propostas já salvas.
- O PDF exportado contém os dados da proposta e valores coerentes com quantidades, subtotais e total.
- Criar ou editar propostas não muda os campos da tela “Impressão” nem exige dados de impressão para itens manuais.
