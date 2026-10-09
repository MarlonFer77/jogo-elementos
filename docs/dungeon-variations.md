# Variações da Ruína Elemental

Implementação local, sem APK, publicação, deploy ou alteração de assinatura.

## Experiência

- Iniciar uma expedição salva os dez encontros e permanece no acampamento.
- Antes de entrar: retrato, tática, HP/AP/XP e dica de contra-ataque. O botão
  de informação revela elementos e descrições dos ataques.
- Elementos e Habilidades reutilizam os catálogos e o gerenciamento existente:
  até quatro elementos desbloqueados e três habilidades descobertas. A árvore
  permanece acessível entre salas. Equipamento só muda após salvar com sucesso.
- Mapa completo recolhido; próximo desafio em destaque. Na horizontal, encontro
  e progresso ficam lado a lado. Entrar/Árvore permanecem fixos; conteúdo pode
  rolar com fonte ampliada. Encerrar está no cabeçalho, com confirmação.
- Tática aparece também na intenção da batalha, com texto/ícone/cor. Animações,
  selos, criaturas, cenários e áudio de combate existentes são reutilizados.

## Regras

`DungeonVariations` contém 30 repertórios: ofensiva, defensiva e controle para
cada uma das dez criaturas. Cada bloco 1–3, 4–6 e 7–9 recebe os três estilos em
ordem sorteada; a variante do dragão é independente. Inimigos não ganham dano,
AP, HP ou XP gratuitos. Permanecem 1.000 XP por conclusão e cura de até 25 HP.

Ofensiva favorece pressão e explosões; defensiva intercala proteções, cura ou
contra-ataque; controle altera o ritmo com Lentidão, Choque, Silêncio ou drenagem
de AP. Há ações básicas entre conjurações. O dragão possui três repertórios e
troca de padrão com metade do HP ou menos, sem alterar a intenção já anunciada.

O mesmo `DungeonOpponent` valida AP/status/equipamento; uma interrupção não é
substituída por uma ação mais forte. Não há adaptação secreta à build do jogador.

## Persistência e compatibilidade

Schema 3, na mesma chave local `dungeon_profile_v1`, guarda dez IDs de tática
em `encounters`. Salvar IDs evita depender da estabilidade do gerador aleatório.
Sair, reabrir, trocar equipamento ou receber recompensa não sorteia outra rota.
Conclusão, derrota e abandono limpam a rota; nova expedição sorteia outra.

Schemas 1/2 migram sem reset: rota vazia mantém o catálogo original até o fim
da tentativa. Rotas incompletas/IDs desconhecidos são rejeitados pelo validador
e seguem a recuperação local existente. Falhas e salvamentos simultâneos não
avançam o estado em memória. Não altera o perfil do Treino nem do Multiplayer.

## Verificação

Testes focados cobrem os 30 repertórios/receitas/ações legais, custo de AP,
distribuição e persistência, migração, limites de equipamento, falha de gravação,
início duplicado, recompensas e fluxo de altares. UI verificada em 360×640 e
568×320, com rotação durante a escolha e fonte ampliada. Capturas opcionais:
`ELEMENTOS_ART_PREVIEW=1`, teste `dungeon_scouting_test.dart`.

Pendente: playtest em celulares para avaliar dificuldade percebida e duração
dos confrontos defensivos. Testes automáticos não substituem esse balanceamento.
