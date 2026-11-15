# Renomear cálculos e adicionar cálculo atual à proposta

## Intenção

Facilitar a organização dos cálculos salvos e permitir incluir o resultado atual da calculadora numa proposta sem primeiro criar um registro simples de cálculo.

## Escopo

- No detalhe de um cálculo salvo, permitir editar o nome e salvar explicitamente. O registro mantém ID, data, parâmetros e resultado originais; só `job.name` muda.
- Na calculadora, adicionar a ação “Adicionar à proposta” junto às ações do resultado. O menu oferece criar uma proposta nova ou escolher uma proposta salva.
- A ação copia nome e preço sugerido atuais para um novo item comercial, sem salvar um `QuoteRecord`. Depois, salva a proposta e abre seu editor.
- Desabilitar a inclusão se não houver preço sugerido válido.
- Se houver uma proposta em edição com alterações não salvas, pedir confirmação antes de descartá-las para continuar a inclusão.
- A ação existente “Salvar orçamento” continua sendo independente; o novo fluxo não cria um cálculo simples por conta própria.

## Abordagem escolhida

1. **Ação direta na calculadora com destino selecionável (escolhida):** permite criar proposta nova ou adicionar à existente sem interromper o fluxo do cálculo. A proposta é atualizada e aberta para revisão.
2. **Incluir o cálculo atual somente no editor da proposta:** reduz ações na tela de impressão, mas exige sair da calculadora e voltar ao editor para buscar o resultado atual.

Para renomear, usar campo editável com botão de salvar no detalhe do cálculo, sem transformar a captura histórica de custos em recálculo.

## Critérios de aceitação

- É possível renomear um cálculo salvo, e o novo nome permanece após reiniciar o app sem alterar valores do registro.
- É possível, a partir de um resultado válido da calculadora, criar uma proposta nova ou escolher uma já salva; o item incluído usa o nome e o preço atuais.
- Adicionar o cálculo atual não cria nem altera um registro simples em “Cálculos salvos”.
- A proposta é persistida e aberta no editor após a inclusão.
- Se o preço não existir, não é possível incluir o resultado na proposta.
- Uma proposta com alterações não salvas não é descartada sem confirmação.
