# Dungeon — Ruína Elemental

Primeiro modo solo offline, acessível em **Dungeon · Solo** na Home.
Perfil separado dos slots A/B do Treino e da identidade Multiplayer; XP local
nunca é enviado ao servidor como recompensa confiável.

## Loop

Escolher 2 elementos → iniciar expedição → reconhecer inimigo e preparar build → enfrentar uma sala → receber XP →
gastar pontos na árvore → próxima sala ou nova expedição.

São **10 salas**, totalizando **1.000 XP**. A resistência aumenta a cada sala;
os patamares seguintes também ampliam o repertório e o AP inicial dos inimigos.

| Sala | Inimigo | HP | AP inicial | XP |
| --- | --- | ---: | ---: | ---: |
| 1 | Goblin das Brasas | 35 | 0 | 40 |
| 2 | Elfa Negra Glacial | 55 | 0 | 60 |
| 3 | Golem do Pântano | 65 | 0 | 70 |
| 4 | Escaravelho Solar | 75 | 1 | 80 |
| 5 | Harpia da Tempestade | 85 | 1 | 90 |
| 6 | Oráculo dos Elfos Negros | 95 | 1 | 100 |
| 7 | Ent do Bosque | 105 | 2 | 110 |
| 8 | Troll dos Trovões | 115 | 2 | 120 |
| 9 | Aranha da Peste | 130 | 2 | 150 |
| 10 | Dragão da Ruína | 150 | 3 | 180 |

## Bestiário visual

Cada sala define uma identidade visual, sem guardar paths de assets no domínio.
`CreatureArt` desenha pixel art original por espécie no Flame e nos retratos do
acampamento. Goblin baixo com orelhas/presas/adaga; elfos negros com cabelo
branco, lança glacial ou cajado; golem rochoso; escaravelho dourado com pinças;
harpia alada; ent com raízes; troll com martelo; aranha de oito patas; dragão
com asas, cauda e chifres. Membros respondem a movimento, ataque e canalização.
Avatares do Treino e Multiplayer permanecem iguais; congelamento e impacto
usam o feedback compartilhado. Nomes/visuais não alteram números, IA, receitas
ou índices de sala nos saves. Não há migração de progresso.

## Intenção e comportamento

Antes de agir, o jogador vê a próxima ação do inimigo e o custo de AP dos
combos. Segurar o aviso exibe a dica completa. Ícones distinguem ataque básico,
conjuração, defesa e quebra de gelo; FÚRIA sinaliza a fase ofensiva do chefe.
A intenção é comprometida durante sua vez: a IA não troca por um ataque mais
forte depois de ver sua jogada. Congelamento cancela a ação; silêncio ou falta
de AP transformam a conjuração em ataque básico, com aviso de interrupção.

Novas expedições possuem três variantes por criatura: ofensiva, defensiva e controle.
O acampamento mostra tática, repertório e dica antes da luta; permite equipar até
4 elementos e 3 habilidades desbloqueadas. Rota salva antes da primeira sala,
sem novo sorteio ao sair/reabrir. Regras em `dungeon-variations.md`.

Expedições antigas em andamento conservam os padrões originais:

- Goblin alterna fogo/vento e Tempestade Ígnea; elfa intercala gelo com recuperação.
- Golem alterna proteção e lentidão; escaravelho alterna seus dois combos de fogo.
- Harpia alterna choque/defesa elétrica; oráculo intercala silêncio e veneno.
- Ent combina proteção e Bosque Sagrado; troll acumula AP para Temporal Elétrico.
- Aranha abre com veneno e acumula AP para Jardim da Peste.
- Dragão prepara Lava e controle; com metade do HP ou menos, seu próximo plano
  entra em FÚRIA e troca defesas por pressão ofensiva. Não ganha AP/dano grátis.

Planos inviáveis já começam como básicos; não há espera infinita por AP nem
controle consecutivo no padrão. Custos e regeneração vêm do mesmo engine.
Padrões reiniciam ao reentrar na sala, como o próprio encontro.

## Regras da expedição

- Variantes equipam de uma a três habilidades conforme a tática; as salas
  continuam crescendo em HP/XP/AP inicial. Padrões antigos são preservados nos saves legados.
- Os padrões das elites reservam ações para acumular AP e conjurar três elementos.
  Dano, custo, regeneração e status continuam seguindo as mesmas regras.
- Nível 1 começa em 0 XP. Primeiro nível exige 40 XP (primeira sala); depois
  os custos são 150, 200, 250… Cada nível concede 1 ponto. Uma expedição
  completa ainda rende 5 pontos. Saves antigos não perdem níveis/compras.
- Cada nó custa 1 ponto e respeita os pré-requisitos da árvore. Os dois
  elementos iniciais são gratuitos. Precisão/multigolpe estão funcionais e
  liberados para compra; detalhes em `skill-tree-completion.md`.
- Os bônus existentes da árvore se aplicam normalmente. Limites de 4 elementos
  e 3 habilidades equipadas são preservados.
- HP restante persiste entre salas; fogueira cura até 25. Seu AP reinicia em 0
  mais bônus de abertura; inimigos começam com o AP listado acima. Status reiniciam
  e bênçãos de abertura são reaplicadas. Após salas 3/6/9, escolha uma bênção
  temporária; regras e opções em `dungeon-blessings.md`.
- Derrota encerra a tentativa, não remove XP/desbloqueios já salvos.
- Sair/fechar durante uma sala reinicia esse encontro no checkpoint, sem XP.
  Descobertas/equipamento da sala são salvos ao concluir vitória ou derrota.

## Integração e persistência

`DungeonProgress` contém regras de nível/pontos. `DungeonCampaign` controla
encontros, checkpoints e intenção; `DungeonOpponent` planeja pelo catálogo e
revalida a ação anunciada antes da execução.
`TrainingScreen` reutiliza combate/HUD/selos com uma sessão opcional de dungeon,
desativa controle do inimigo e não grava nos slots do Treino neste modo.

`dungeon_profile_v1` guarda o JSON schema 3 em SharedPreferences, com migração
dos schemas 1/2 e backup local anterior. IDs das bênçãos e das variantes são
temporários por tentativa; rotas antigas vazias representam os encontros originais.
Recompensa e avanço de sala são gravados juntos; o estado em memória só avança
após sucesso. Resultado duplicado/antigo é rejeitado. Save ilegível bloqueia
a carga com aviso, sem sobrescrever dados. Não há backup em nuvem neste bloco.
Saves anteriores de três salas mantêm XP, pontos, conquistas e índice da sala;
uma tentativa ativa continua pela lista ampliada, sem recompensar salas antigas.

IA tem HP definido por sala, mas usa os mesmos custos/status/dano. Ela escolhe
básicos, habilidade equipada ou defesa; conjurações são telegrafadas na arena.
O jogador continua executando seus selos. Evolução da árvore ocorre fora da luta.

Limites atuais: uma ruína de dez salas com variantes de combate, sem geração de mapa ou dificuldade adaptativa
ou integração de recompensas online. Balanceamento inicial requer playtest real.
