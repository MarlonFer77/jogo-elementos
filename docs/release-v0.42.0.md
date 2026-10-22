# Elementos v0.42.0 — Uma conta, todos os modos

## Correções

- Login e cadastro agora pertencem ao aplicativo inteiro, antes do menu.
- Fluxo de entrada: abertura animada → conta Elementos → menu de todos os modos.
- Treino, batalha 2D, Dungeon, Multiplayer e BETA TEST usam a mesma entrada.
- Contas existentes continuam válidas; sessão confirmada permite acessar os
  modos locais offline neste aparelho.
- “Minha conta” no menu principal mostra o ID e permite sair. A saída fecha as
  telas abertas para não manter a sessão anterior acessível.
- BETA TEST não possui mais cadastro próprio: mantém sua senha de testador e
  os checkpoints da aventura, utilizando a conta do Elementos.
- Identificação global na abertura e ajuste dos atalhos no menu horizontal.

## Atualização

Instale **app-release.apk** por cima da versão anterior, **sem desinstalar nem
limpar os dados**. A versão deve aparecer como **0.42.0**.

Use o mesmo e-mail da conta que já utilizava. O primeiro acesso/cadastro e a
confirmação de e-mail precisam de internet; depois, os modos locais podem ser
acessados offline com a sessão confirmada armazenada.

Saves e compras locais foram preservados, sem migração. Conta única não significa
sincronização automática: a aventura BETA continua salva por ID neste aparelho;
Treino, Dungeon e loja mantêm seu armazenamento local existente.

33 testes focados passaram e a análise estática ficou limpa. Verificados login,
cadastro, confirmação, saída, dados preservados, abertura, atualizador e layouts
vertical/horizontal. Validação física no Android continua necessária.

Nenhuma mudança de servidor. O modo BETA continua experimental. A assinatura
definitiva continua pendente; esta versão mantém a assinatura anterior para
permitir atualização sem apagar dados.
