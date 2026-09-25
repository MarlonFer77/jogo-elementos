# Livro de Descobertas

Publicado na v0.25.0.

- Ícone de livro nas batalhas do Treino e Multiplayer.
- Progresso conhecido/total, slots equipados, busca sem distinção de acentos e
  filtros combináveis por elemento, custo base e equipamento.
- Detalhes expansíveis: receita conhecida, dano/AP base, descrição dos efeitos
  e dificuldade do selo. Build/status continuam sendo considerados na prévia real.
- Combinações não descobertas não entram na projeção da tela: só a contagem é exibida.
- No Treino, registro compartilhado existente não concede habilidades ao outro
  jogador. O livro distingue receita registrada, habilidade pessoal e equipamento.
- Gerenciar habilidades reutiliza `AttacksScreen` e os callbacks de salvamento
  existentes. O livro relê o estado ao voltar; não cria inventário/salvamento paralelo.
- Disponibilidade é consultada ao abrir/atualizar, sem requests adicionais por
  receita. No Multiplayer a ação e o equipamento continuam validados pelo servidor.

Validação focada: catálogo/filtros, ocultação de receitas, atualização após equipar,
layout vertical/horizontal e testes existentes do gerenciador de ataques.
